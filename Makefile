.PHONY: posts
posts:
	# Call R to make the site
	R --vanilla --slave -f 'make.R'

run: posts
	bundle exec jekyll serve --baseurl ''

.PHONY: clean
clean:
	rm -rf _posts/*md cache/*
