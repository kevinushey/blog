all:
	# Call R to make the site
	R --vanilla --slave -f 'make.R'

run:
	R --vanilla --slave -f 'make.R'
	jekyll serve --baseurl ''

