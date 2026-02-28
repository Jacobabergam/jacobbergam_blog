# Build and serve Jekyll with Ruby 3.2 and build tools (for native gems).
# Build: docker build -t jekyll-blog . && docker run --rm -v "$(pwd)":/srv/jekyll jekyll-blog jekyll build
# Serve: docker run --rm -it -p 4000:4000 -v "$(pwd)":/srv/jekyll jekyll-blog jekyll serve

FROM ruby:3.2-bookworm

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/jekyll

RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["jekyll", "build"]
