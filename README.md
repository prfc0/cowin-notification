# cowin-notification
Notification over email whenever a slot for 18+ becomes available district wise

Public APIs: https://apisetu.gov.in/public/marketplace/api/cowin/cowin-public-v2

This tool helps in alerting a person whenever a center has opened vaccinations for 18-44 years.

Input needed. 

1. Districts users are interested it.
To get the district id for a given district, run get_districts.pl to generate a csv file which will have all the Indian districts.
From there, one can find out the district id.

2. From email/password.
This tool uses Email::Send::SMTP::Gmail module so you would need an gmail account's credentials.

3. To emails.
List of users to send email to.

Software needed:

1. Unix/Mac
2. Perl
3. Perl modules
3.1 JSON::XS
3.2 Email::Send::SMTP::Gmail

Examples:

$ src/get_seats_by_district.pl --district_id 581 --district_id 582 --from_email someone@gmail.com --email_password "password" --to_email user1@example.com,user2@example.com
