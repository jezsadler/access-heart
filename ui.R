#
# UI file for the AccessHeart Shiny app.
# 

library(shiny)
library(shinythemes)
library(shinyjs)

# Style for the loading page.
appCSS <- "
#loading-content {
  position: absolute;
  background: #2B3E50;
  opacity: 0.9;
  z-index: 100;
  left: 0;
  right: 0;
  height: 100%;
  text-align: center;
  color: #FFFFFF;
}
"


# Set the Shiny theme.
shinyUI(fluidPage(
    theme = shinytheme("superhero"),
    # Include your Google Analytics script here for tracking.
    tags$head(includeScript("google-analytics.js")),
    useShinyjs(),
    inlineCSS(appCSS),
    tags$style(type = "text/css", "
      .irs-min {color: #2B3E50;background: #2B3E50;}
      .irs-max {color: #2B3E50;background: #2B3E50;}
      "),

    # Get geolocation
    tags$script('
        $(document).ready(function () {
        
            navigator.geolocation.getCurrentPosition(onSuccess, onError);
            
            function onError (err) {Shiny.onInputChange("geolocation", false);}
            
            function onSuccess (position) {
                setTimeout(function () {
                    var coords = position.coords;
                    console.log(coords.latitude + ", " + coords.longitude);
                    Shiny.onInputChange("geolocation", true);
                    Shiny.onInputChange("lat", coords.latitude);
                    Shiny.onInputChange("long", coords.longitude);
                    }, 1100)
                }
            });
    '),
    
    # On application start, show loading screen while all the elements load.
    div(
        id = "loading-content",
        h2("Loading AccessHeart...")
    ),
    
    # Main application UI.
    hidden(div(
        id = "app-content",
      
        # Title - shown on all pages.
        titlePanel("AccessHeart Cardiovascular Disease Risk Calculator"),
        hr(),
        mainPanel( 
        # We're implementing the form as a set of divs which show and hide dynamically as the user moves through them.
            div(
                # The first tab is the user data input form, which collects age and blood pressure.. 
                id = "form_page",
                div("Welcome to the AccessHeart cardiovascular disease risk calculator. Please enter your information below:"),
                hr(),
                sliderInput("age", "Age (years)",18,80,40),
                hr(),
                div("Blood Pressure (mm Hg):"),
                h2(textOutput("bp_all")),
                sliderInput("ap_hi", "Systolic",0,200,120),
                sliderInput("ap_lo", "Diastolic",0,200,80),
                hr(),
                # Get consent to store user data.
                fluidRow(
                    column(3,checkboxInput("storedata","I consent to my anonymous data being stored for auditing purposes",value = TRUE)),
                    column(1,actionButton("submit", "Submit", class = "btn-primary"))
                )
                ),
            hidden(div(
                # The second page shows the results of the CVD risk model. If their risk is under 10%, the 
                # application won't go further; if it's over 10%, they will be sent on to the quiz page.
                id = "results_page",
                div("Your risk of cardiovascular disease is:"),
                h2(textOutput("riskpct")),
                textOutput("riskrecc"),
                hr(),
                fluidRow(
                    column(2,offset = 0, actionButton("back1", "Back", class = "btn-primary")),
                    column(2,offset = 1, uiOutput("to_quiz"))
                    )
                )),
            hidden(div(
                # The third page is a form for the user to describe their lifestyle, which is used for 
                # determining appropriate recommended actions.
                id = "quiz_page",
                # Allow them to select metric or US/imperial units for height and weight.
                checkboxInput("metric","I use metric units"),
                conditionalPanel(
                  condition = "input.metric == true",
                  sliderInput("mtheight", "Height (cm)",1,250,168),
                  sliderInput("mtweight", "Weight (kg)",1,200,84)
                ),
                conditionalPanel(
                  condition = "input.metric == false",
                  sliderInput("usheight", "Height (in)",1,100,66),
                  sliderInput("usweight", "Weight (lbs)",1,500,185)
                ),
                hr(),
                # Questions about their lifestyle.
                selectInput("chol", "Have you had your cholesterol checked in the past year?",c("Yes","No"), selected = "No"),
                selectInput("glucose", "Have you had your blood sugar checked in the past year?",c("Yes","No"), selected = 
                              "No"),
                selectInput("smoke", "Do you currently use tobacco or nicotine?", c("Yes","No"), selected = "Yes"),
                selectInput("active", 
                            "Do you get at least 75 minutes of vigorous exercise or 150 minutes of moderate exercise each week?", 
                            c("Yes", "No"), selected = "No"),
                hr(),
                # We take a guess at their zip code based on browser location, and allow them to enter a different ZIP
                # if they prefer.
                div("Enter your ZIP code for pricing in your area:"),
                numericInput("usr_zip",label=NULL,value = 0,max= 99999),
                hr(),
                fluidRow(
                  column(2,offset = 0, actionButton("back2", "Back", class = "btn-primary")),
                  column(2,offset = 1, actionButton("recs_button","Get Recommendations", class = "btn-primary"))
                )
            )),
            hidden(div(
                # The last page displays personal recommendations with local costs.
                id = "costs_page",
                textOutput("recs_intro"),
                tableOutput("risktable"),
                textOutput("thanks"),
                hr(),
                actionButton("back3", "Back", class = "btn-primary")
                )
                )
            )
    ) 
    )
    )
)
