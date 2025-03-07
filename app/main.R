##############################
#
# Scrape pararius new rentals
#  in The Hague and store in
#  database
#
#############################

## Libraries
library(listings)
library(reticulate)

## Load settings
settings <- yaml::read_yaml("/root/pararius/settings.yml")

## Get environment variables
if(Sys.getenv("MAIL_HOST") == "" |
   Sys.getenv("MAIL_PORT") == "" |
   Sys.getenv("MAIL_USER") == "" |
   Sys.getenv("MAIL_PWD") == "") {

  stop("One or more environment variables not found! Cannot send emails")

}

settings$place <- if (Sys.getenv("S_PLACE") != "") Sys.getenv("S_PLACE") else settings$place
settings$min_price <- if (Sys.getenv("S_MIN_PRICE") != "") as.integer(Sys.getenv("S_MIN_PRICE")) else settings$min_price
settings$max_price <- if (Sys.getenv("S_MAX_PRICE") != "") as.integer(Sys.getenv("S_MAX_PRICE")) else settings$max_price
settings$bedrooms <- if (Sys.getenv("S_BEDROOMS") != "") as.integer(Sys.getenv("S_BEDROOMS")) else settings$bedrooms
settings$email_to <- if (Sys.getenv("S_MAIL_TO") != "") Sys.getenv("S_MAIL_TO") else settings$email_to
settings$email_from <- if (Sys.getenv("S_MAIL_FROM") != "") Sys.getenv("S_MAIL_FROM") else settings$email_from


## Initialize
p <- Pararius(settings$place,
              settings$min_price,
              settings$max_price,
              settings$bedrooms,
              list(settings$blacklist))

## Scrape results, filter & store in database
new <- update_rentals(p)

# If not null

if(nrow(new) > 0) {

   ## New listings will be sent as mail
   msg <- paste0(
     '<html>',
     '<body>',
     '<p>Hi there! I found one or more new listings in ', settings$place, ' you might find iteresting!</p>',
     '<br>',
     '<div>',
     paste0(
       '<ul>',
       '<li>',
       '<p>url: www.pararius.nl',new$url, '</p>',
       '</li>',
       '<li>',
       '<p>bedrooms: ',new$bedrooms, '</p>',
       '</li>',
       '<li>',
       '<p>name: ',new$name, '</p>',
       '</li>',
       '<li>',
       '<p>realtor: ',new$agent, '</p>',
       '</li>',
       '<li>',
       '<p>price: ',new$price, ' (', ifelse(new$inclusive, "inclusive", "exclusive"),')', '</p>',
       '</li>',
       '</ul>',
       collapse = "<br>"
     ),
     '</div>',
     '</body>',
     '</html>'
   )
   
   # Use reticulate to build bridge between python & R
   
   ## Import modules 
   smtplib <- import("smtplib")
   email <- import("email")
   
   ## Set up email
   multipart <- email$mime$Multipart$MIMEMultipart('alternative')
   multipart$set_param("From", settings$email_from)
   multipart$set_param("To", settings$email_to)
   multipart$set_param("Subject", "Found new listings!")
   
   ## Record body
   body <- email$mime$Text$MIMEText(msg, 'html')

   ## Attach 
   multipart$attach(body)
   
   ## Log in to gmail
   server <- smtplib$SMTP(Sys.getenv("MAIL_HOST"), 
                          Sys.getenv("MAIL_PORT"))
   server$starttls()
   server$login(Sys.getenv("MAIL_USER"), 
                Sys.getenv("MAIL_PWD"))
   
   ## Send
   server$sendmail(settings$email_from, settings$email_to, multipart$as_string())
   
   ## Quit server 
   server$quit()
   
   ## Cat
   message("Email sent! Quitting program.")

}