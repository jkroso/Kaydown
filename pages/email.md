# Email

Kaydown can keep a copy of your email in a folder on this Mac. The folder has the same folders in it as your email server has. Each email is one `.eml` file: the email as the server sent it, with what was attached to it inside. Kaydown shows it as a page. You read it there, and you can't change it: Kaydown marks each email file as read-only on your Mac, so no other app changes one by mistake. Click a link in an email to open it. An email that you write is a Markdown page until you send it.

## Your account

```ui
email_form()
```

Type your address, and Kaydown says which password your email company takes. For an address at a domain of your own, like a business address, Kaydown asks the internet which company takes that domain's email, to find its servers.

Kaydown keeps the password in the Keychain of this Mac, and nowhere else.

Your email goes in a folder that's named for your address. Kaydown makes that folder in a folder called Mail in your home folder, unless you choose another one. To choose, click a name in the path to go to that folder, and the last name to list the folders in it. Choose, beside the path, asks for a folder with the Mac's own panel, which can make a new one. The folder that you choose can have other things in it, because Kaydown only uses the folder that's named for your address. If you change the folder later, Kaydown gets your email again into the new folder, and leaves the old folder as it is.

## What Kaydown gets

Kaydown gets your inbox first. Choose how far back the emails that it gets go.

```ui
months = [1, 3, 12, 36, 0]
names = ["1 month", "3 months", "1 year", "3 years", "Every email"]
RadioGroup(labels=names, selected=something(findfirst(==(email_back()), months), 3),
           onchange=group -> email_back!(months[group.selected]))
```

```ui
Checkbox(label="Get the other folders too, once the inbox has come", checked=email_rest(), onchange=box -> email_rest!(box.checked))
```

Kaydown looks at the inbox as often as ever while the other folders come. Without the other folders, Kaydown still makes each one on this Mac, with nothing in it. If you choose a longer time later, Kaydown gets the older emails. If you choose a shorter time, the emails that have come stay.

## New email

```ui
say(text) = Text(text, size=page_text_size() * 1px)
Column(Alignment.Start, child_gap=12px, say(email_news()),
       Row(child_gap=8px, Button(label="Look for email now", onclick=button -> email_check!()),
                          Button(label="Show the inbox", onclick=button -> email_show!())))
```

```ui
minutes = [1, 5, 15, 30, 60]
names = ["Every minute", "Every 5 minutes", "Every 15 minutes", "Every 30 minutes", "Every hour"]
RadioGroup(labels=names, selected=something(findfirst(==(email_every()), minutes), 2),
           onchange=group -> email_every!(minutes[group.selected]))
```

The first time, Kaydown gets every email of the time that you chose, the newest first. That can take a long time. The form above shows how many emails have come, and how long the rest take. You can read the ones that have come while the rest come.

Gmail lets an app get 2,500 MB of email in a day. Kaydown stops before that, and goes on a day later. So the first time can take a few days for a Gmail account with many attached files.

## How it works

The server is the one that's right. An email that you delete in another app goes from the folder here. An email file that you move or delete in the Finder comes back the next time Kaydown looks. Each folder also has a hidden list of its emails. If that list is lost, Kaydown makes it again from the files and the server, with no new download.

These change what the server has:

- Reading an email marks it as read.
- The buttons at the top of an email answer it, send it on, archive it and delete it.
- A new email, and an answer, is a page with `to` and `subject` at its top. ⌘⇧Return sends it. A line that holds only a link to a file sends the file with it.

The Key bindings page lists the keys of each of these.
