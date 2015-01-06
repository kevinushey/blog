all:
	# Call R to make the site
	R --vanilla --slave -f 'make.R'

run:
	jekyll serve --baseurl ''

