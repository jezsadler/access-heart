#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(shinythemes)
library(shinyjs)


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
    
    div(
        id = "loading-content",
        h2("Loading AccessHeart...")
    ),
    
    # Application title
    hidden(div(
        id = "app-content",
        titlePanel("AccessHeart Cardiovascular Disease Risk Calculator"),
        hr(),
        mainPanel( 
        # We're implementing the form as a set of divs which show and hide dynamically as the user moves through them.
            div(
                # The first tab is the user data input form. 
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
                fluidRow(
                    column(3,checkboxInput("storedata","I consent to my anonymous data being stored for auditing purposes",value = TRUE)),
                    column(1,actionButton("submit", "Submit", class = "btn-primary"))
                )
                ),
            hidden(div(
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
                id = "quiz_page",
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
                selectInput("chol", "Have you had your cholesterol checked in the past year?",c("Yes","No"), selected = "No"),
                selectInput("glucose", "Have you had your blood sugar checked in the past year?",c("Yes","No"), selected = 
                              "No"),
                selectInput("smoke", "Do you currently use tobacco or nicotine?", c("Yes","No"), selected = "Yes"),
                selectInput("active", 
                            "Do you get at least 75 minutes of vigorous exercise or 150 minutes of moderate exercise each week?", 
                            c("Yes", "No"), selected = "No"),
                hr(),
                div("Enter your ZIP code for pricing in your area:"),
                numericInput("usr_zip",label=NULL,value = 0,max= 99999),
                hr(),
                fluidRow(
                  column(2,offset = 0, actionButton("back2", "Back", class = "btn-primary")),
                  column(2,offset = 1, actionButton("recs_button","Get Recommendations", class = "btn-primary"))
                )
            )),
            hidden(div(
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