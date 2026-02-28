---
layout: reading
title: Reading
order: 2
---

<div class="page">
  <h1 class="page-title">{{ page.title }}</h1>
  <p class="reading-intro">From <a href="https://www.goodreads.com/user/show/114910493-jacob-bergam">Goodreads</a>.{% if site.amazon_associate_tag and site.amazon_associate_tag != "" %} Book links may go to Amazon; as an Amazon Associate I earn from qualifying purchases.{% endif %}</p>

  {% if site.data.recently_read and site.data.recently_read.books %}
    {% assign batch_size = 24 %}
    <nav class="reading-grid" aria-label="Books read">
      {% for book in site.data.recently_read.books %}
        {% if book.cover_url %}
          {% capture book_href %}{% include book_link_url.html book=book %}{% endcapture %}
          <a href="{{ book_href | strip }}" class="reading-grid__item {% if forloop.index0 >= batch_size %}reading-grid__item--hidden{% endif %}" target="_blank" rel="noopener noreferrer" title="{{ book.title }}">
            <img src="{{ book.cover_url }}" alt="" class="reading-grid__cover" loading="lazy" />
          </a>
        {% endif %}
      {% endfor %}
      <div class="reading-grid__sentinel" id="reading-sentinel" aria-hidden="true"></div>
    </nav>
  {% else %}
    <p>Run <code>ruby scripts/fetch_goodreads.rb</code> to populate recently read books.</p>
  {% endif %}
</div>
