
SRCS	:= $(wildcard *.html *.sgml *.xml)
NSGMLS	:= $(shell if command -v onsgmls 2>/dev/null; then	 \
			:					;\
		   elif command -v nsgmls 2>/dev/null; then	 \
			:					;\
		   else						 \
			echo "false"				;\
			echo "warning: no cvs2cl found" 1>&2	;\
		   fi)

.PHONY: validate
validate:	$(addsuffix .validate,$(SRCS))

# /usr/share/sgml/declaration/xml.dcl removed from $(NSGMLS) command line since
# it produces a warning, and the XHTML DTD already refer to the xml declaration.
%.xml.validate : %.xml
	SP_CHARSET_FIXED=YES SP_ENCODING=XML $(NSGMLS) -wxml -wall -gues $<

%.validate : %
	$(NSGMLS) -wall -gues $<

debian-man-refs.xml:	/tmp/debian-man-ref.ent

/tmp/debian-man-ref.ent:	../create-debian-man-refs.sh
	../create-debian-man-refs.sh > $@
