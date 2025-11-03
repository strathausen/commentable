# commentable space

## description

The app will be a saas for minimal flat comments in a neo-brutalist design.

## technologies

For the comment side, use minimal javascript, or none if possible, and basic css.
For the user dashboard, feel free to use vanilla javascript or something lightweight, like htmx or alpine.

## specification

Users can authenticate in via email and add their website.
Users can maintain a list of moderation prompts per website.
Users can create an embed code as iframe or external link as such: <link-to-our-server>/user-website-uuid?url=<website-url-with-comments>. The url parameter can be left blank and created automatically by the user when they use the embed code on their website.

Comments can be anonymous and will be moderated via some llm open-ai moderation model.

Users can see a dashboard when they log in:
- a list of their websites (created via the dashboard) with some basic stats
- go to a website detail page where they can edit and archive the website

on the website detail page:
- see embed code and stand alone link to copy easily. please mention that the url= parameter needs to be set!
- a list of links for each page (automatically created when the embed code or link is used)
- a list of comments for each page
- a list of moderation prompts for the website (maintained by the user)
- a way to re-run moderation after changing a prompt
- a way to manually moderate comments - manual moderation won't be overwritten by subsequent llm moderation runs

a page can be archived.


## authentication flow

users will get a login link via email. we don't store passwords. use resend for emails - the credential is in .env
