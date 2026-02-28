# Jacob's Blog

Repo contains the data for my personal blog!

### In Development

**RUN**
```bash
docker build -t jekyll-blog .
docker run --rm -it -p 4000:4000 -v "$(pwd)":/srv/jekyll jekyll-blog jekyll serve --host 0.0.0.0
```