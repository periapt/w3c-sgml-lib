#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use English qw ( -no_match_vars );
use Readonly;
use XML::LibXML;
use autodie qw(open close);

Readonly my $SOURCE_DIR => 'htdocs/sgml-lib';
Readonly my $CATALOG_XML => 'catalog.xml';
Readonly my $DEST_DIR => 'usr/share/xml/w3c-sgml-lib/schema/dtd';

# Sanity check the files
foreach my $file ('debian', $SOURCE_DIR) {
    if (! -d $file) {
        croak "Cannot find directory $file";
    }
}
foreach my $file ($CATALOG_XML) {
    if (! -r "$SOURCE_DIR/$file") {
        croak "Cannot read $file";
    }
}
open(my $fh, '>', 'debian/xmlcatalogs');
print {$fh} "local;$SOURCE_DIR/$CATALOG_XML;/$DEST_DIR/$CATALOG_XML\n";

# Set up XML processing machinery
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file("$SOURCE_DIR/$CATALOG_XML");
my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs('x', $doc->getDocumentElement->getNamespaces->getValue);

# Write new catalog.xml and populate memory structures
my @nodes_with_uri = $xpc->findnodes('//*[@uri]', $doc);
foreach my $node (@nodes_with_uri) {
    my $uri = $node->getAttribute('uri');
    my $name = $node->nodeName;
    my $id = ($name eq 'public') ? $node->getAttribute('publicId')
            : ($name eq 'system') ? $node->getAttribute('systemId')
            : croak "unrecognized elemeny: $name";

    print {$fh} "root;$name;$id\n";
    print {$fh} "package;$name;$id;/$DEST_DIR/$CATALOG_XML\n";
    print {$fh} "\n";
}

close $fh;
exit(0);

# Copyright 2010, Nicholas Bamber, Artistic License

