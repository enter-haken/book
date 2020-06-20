# springer link

Due to the covid 19 outbreak [springer is launching a global program][1] to support learning worldwilde.

Harish Narayanan build a [small python project][2] to build a static website from the springer provided excel files.
The [result][3] looks interesting, because you can use the book links, without having excel installed.

<!--more-->

The [script][4] looks as following:

```
rt pandas as pd
from jinja2 import Environment, FileSystemLoader


books_df = pd.read_excel("./input/Free+English+textbooks.xlsx")
grouped_books_df = books_df.groupby(["English Package Name"])


loader = FileSystemLoader(searchpath="./templates/")
env = Environment(loader=loader)
template = env.get_template("index.html")

grouped_books = {}

for group, books in grouped_books_df:
    grouped_books[group] = []
        for book in books.iterrows():
                  grouped_books[group].append(book)

                  rendered_template = template.render(grouped_books=grouped_books)

with open("index.html", "w") as f:
    f.write(rendered_template)
```

Just a few lines of python and an excel sheet looks much nicer. 

[1]: https://www.springernature.com/gp/librarians/news-events/all-news-articles/industry-news-initiatives/free-access-to-textbooks-for-institutions-affected-by-coronaviru/17855960
[2]: https://github.com/hnarayanan/springer-books
[3]: https://hnarayanan.github.io/springer-books/ 
[4]: https://github.com/hnarayanan/springer-books/blob/master/generate.py 
