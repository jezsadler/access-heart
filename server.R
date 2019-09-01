#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(googlesheets)
library(zipcode)
library(rms)

# Get the auth token for Google Sheets.
gs_auth(token="ttt.rds")

# Load the trained risk prediction model.
load("model.3sd.rda")

# Get zip code location data
data(zipcode)
cost_table <- zipcode

cost_data <- read.csv("costs_2019-08-11.csv",stringsAsFactors = FALSE)

cost_table <- merge(cost_table,cost_data,by.x = "state",by.y = "Location",all.x = TRUE)

# Fill in missing values with the national average
cost_table[is.na(cost_table["Cholesterol.Test.Average"]),"Cholesterol.Test.Average"] <- cost_data[
    cost_data["Location"] == "National Average","Cholesterol.Test.Average"]

cost_table[is.na(cost_table["Cholesterol.Test.State.Range"]),"Cholesterol.Test.State.Range"] <- cost_data[
    cost_data["Location"] == "National Average","Cholesterol.Test.State.Range"]

cost_table[is.na(cost_table["HBP_Average"]),"HBP_Average"] <- cost_data[
    cost_data["Location"] == "National Average","HBP_Average"]

cost_table[is.na(cost_table["HBP_Range"]),"HBP_Range"] <- cost_data[
    cost_data["Location"] == "National Average","HBP_Range"]

cost_table[is.na(cost_table["DocVisit_Average"]),"DocVisit_Average"] <- cost_data[
    cost_data["Location"] == "National Average","DocVisit_Average"]

cost_table[is.na(cost_table["DocVisit_Range"]),"DocVisit_Range"] <- cost_data[
    cost_data["Location"] == "National Average","DocVisit_Range"]


# Load in the text recommendations.
recco_text <- read.csv("recco_text.csv",header=FALSE,row.names=1,stringsAsFactors = FALSE)

# Set the threshold for action.
THRESH <- 0.1

shinyServer(function(input, output,session) {
    # Connect to Google Sheets
    usrdata_gs <- gs_key("1cRii1WlVb_hcBduog9e7C_s5KmmJLsvVsv8tVBKklaE")
    # Display blood pressure as a nice big fraction.
    output$bp_all <- renderText({
        paste0(input$ap_hi,"/",input$ap_lo)
    })
    # Set up a place to store the risk level between actions
    values <- reactiveValues()

    Sys.sleep(3)
    # Hide the loading message when the rest of the server function has executed
    hide(id = "loading-content", anim = TRUE, animType = "fade")    
    showElement("app-content")
    # When they submit the form:
    observeEvent(input$submit, {
 
        # Capture time and location
        sess_data = data.frame(location=paste0(input$lat,",",input$long), time=date())
        
        # Save location to reactive vals
        values$lat <- input$lat
        values$long <- input$long
        
        # Capture form data.
        user_input <- data.frame(age=input$age,ap_hi=input$ap_hi,ap_lo=input$ap_lo)
        
        # Run form data through the model to get a risk probability.
        risk <- plogis(predict(model.3sd$miniModel, newdata = user_input))
        
        # Display as a percentage.
        output$riskpct <- renderText(paste0(round(100*risk),"%"))
        
        # Categorize risk as low/medium/high.
        risklvl <- if(risk <= THRESH) "low" else "high"
                
        # Save model results in a data frame.
        user_results <- data.frame(cvd_risk=risk,cvd_level=risklvl)

        # Record the risk and risk level for costing purposes        
        values$risk <- risk
        values$risklvl <- risklvl
        
        # Provide recommendations based on risk levels.
        output$riskrecc <- renderText(
            switch(
                risklvl,
                low = "You are at low risk of cardiovascular disease. Thank you for using AccessHeart.",
                high = "You have an elevated risk of cardiovascular disease. For personalized recommendations, click Next."
                )
            )
        
        
        output$to_quiz <- renderUI({
            if(risklvl != "low") {
                actionButton("quiz_button", "Next", class = "btn-primary")
            }
        })

        # Stick all our data together.
        usrdata = cbind(sess_data,user_input,user_results)
        
        # Label columns nicely.
        names(usrdata) <- c(
            "Location","Time","Age","Systolic BP","Diastolic BP","Cardiovascular Disease risk","CVD Risk level")
        
        # If the user has consented, write the results to the Google Sheet
        if(input$storedata == TRUE){gs_add_row(usrdata_gs, ws = "Short", input = usrdata)}
        
                
        # Move to the Results page.
        hideElement(id = "form_page")    
        showElement(id = "results_page")
        
          
        })
    
    # Back button from the results page to the form.
    observeEvent(input$back1, {
        hideElement(id = "results_page")    
        showElement(id = "form_page")
    })

    # When they go to the quiz page.
    observeEvent(input$quiz_button, {
        # Find cartesian distance between user location and the centroids of each zip code.
        cost_table["usr_cart"] <- sqrt((cost_table["latitude"] - input$lat)^2 + (cost_table["longitude"] - input$long)^2)
        
        # Pick the zip code with closest centroid.
        user_zip_guess <- cost_table[which.min(cost_table$usr_cart),"zip"]

        # Pre-populate the zipcode on the cost form. 
        updateNumericInput(session, "usr_zip", value = user_zip_guess)
        
        hideElement(id = "results_page")    
        showElement(id = "quiz_page")
    })
    
    
    # Back from quiz page to results page.
    observeEvent(input$back2, {
        hideElement(id = "quiz_page")    
        showElement(id = "results_page")
    })
    
    observeEvent(input$recs_button, {
        # Find where the user is.
        usr_city <- cost_table[cost_table["zip"] == input$usr_zip,"city"]
        usr_state <- cost_table[cost_table["zip"] == input$usr_zip,"state"]
        
        # Look up costs for visit and test
        usr_costlist <- cost_table[which(cost_table["zip"] == input$usr_zip),7:12]
        
        # Information needed for detailed recommendations. 
        # Initialize an array for the text.
        reccos <- data.frame(Recommendation=character(),Cost=character(),stringsAsFactors = FALSE)
        
        # If they smoke, they should not do that.
        if(input$smoke == "Yes"){reccos <- rbind(reccos,data.frame(Recommendation=recco_text["smok_recc_text",],Cost="Free"))}
        
        # If they are not active, they should be.
        if(input$active == "No"){reccos <- rbind(reccos,data.frame(Recommendation=recco_text["active_recc_text",],Cost="Free"))}
        
        # If they are in a suitable age bracket, recommend cholesterol checking.
        if (input$age >= 40 & input$age < 76 & input$chol == "No"){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["dyslipidemia_recc_text",],Cost=paste0("$",unlist(usr_costlist[2]))))}

        # If the users use US units, convert to metric.        
        if(input$metric == TRUE){
            height <- input$mtheight
            weight <- input$mtweight
        } else {
            height <- input$usheight*2.54
            weight <- input$usweight/2.205
        }
        
                
        # Calculate BMI and hypertension state.
        bmi <- 10000*weight/(height^2)
        
        if(input$ap_hi >= 140 & input$ap_lo >= 90)
        {hypertension <- 2}else 
            if((input$ap_hi < 140 & input$ap_hi >=130) | input$ap_lo >= 80){hypertension <- 1} else 
                if (input$ap_hi < 130 & input$ap_lo < 80){hypertension <- 0} 
        
        if(bmi >= 30 & hypertension > 0){reccos <- rbind(reccos,data.frame(Recommendation=recco_text["bmi_recc_text_1",],Cost=paste0("$",unlist(usr_costlist[6]))))}

        if(input$age >= 40 & input$age <= 75 & bmi < 30 & hypertension == 0 & input$glucose == "Yes" & values$risk >= THRESH){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["chol_recc_text_1",],Cost=paste0("$",unlist(usr_costlist[2]))))
        } 
        
        if (hypertension == 2){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["hbp_recc_text_1",],Cost=paste0("$",unlist(usr_costlist[4]))))
        } else if (hypertension == 1){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["hbp_recc_text_2",],Cost=paste0("$",unlist(usr_costlist[4]))))
        } else if (hypertension == 0) {
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["hbp_recc_text_3",],Cost="Free"))
        }        
       
        # If in a suitable age and weight range, recommend glucose testing.
        if (input$age >= 40 & input$age < 71 & bmi > 25 & input$glucose == "No"){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["glucose_recc_text_1",],Cost=paste0("$",unlist(usr_costlist[6]))))
        } else if (input$glucose == "No"){
            reccos <- rbind(reccos,data.frame(Recommendation=recco_text["glucose_recc_text_2",],Cost=paste0("$",unlist(usr_costlist[6]))))
            }
            

        
        # Appropriate text to describe the user's situation.
        output$recs_intro <- renderText(paste0("These are your personalized heart health recommendations, with the average costs in ",
                                               input$usr_zip," (",usr_city,", ",usr_state,"):"))
                                        
        
        # Provide recommendations based on risk levels.
        output$risktable <- renderTable(reccos, striped = TRUE)
        
        # Thank you message to show they're done.
        output$thanks <- renderText("Thank you for using AccessHeart.")
        
        hideElement(id = "quiz_page")    
        showElement(id = "costs_page")
    })
    

    # Back button from the costs page to the lifestyle quiz page.
    observeEvent(input$back3, {
        hideElement(id = "costs_page")    
        showElement(id = "quiz_page")
    })
    })