#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use English qw ( -no_match_vars );
use Readonly;
use XML::LibXML;
use autodie qw(open close);
use File::Find;
use File::Slurp;
use File::Basename;

Readonly my $SOURCE_DIR => 'htdocs/sgml-lib';
Readonly my $CATALOG_XML => 'catalog.xml';
Readonly my $DEST_DIR => 'usr/share/xml/w3c-sgml-lib/schema/dtd';

Readonly my $LEGACY_DTD_DIR => 'usr/share/xml/xhtml/schema/dtd';
Readonly my $LEGACY_ENT_DIR => 'usr/share/xml/entities/xhtml';
Readonly my $LEGACY_SRC_DIR => 'debian/legacy';
Readonly my $LEGACY_MATCH_RE => qr{\A[\w\-]+\.(ent|dtd|mod)\z}xms;
Readonly my $LEGACY_MATCH_ENT_RE => qr{\A[\w\-\/]+\.ent\z}xms;
Readonly my $PUBLIC_ID_RE => qr{^\s*PUBLIC\s+\"([\-\/\w\.\s]+)\"\s*$}xms;
Readonly my %LEGACY_DCL_LINKS => (
    "$LEGACY_DTD_DIR/1.0/xhtml1.dcl" => 'usr/share/xml/declaration/xml.dcl',
    "$LEGACY_DTD_DIR/1.1/xml1.dcl" => 'usr/share/xml/declaration/xml.dcl',
    "$LEGACY_DTD_DIR/1.1/xml1n.dcl" => 'usr/share/xml/declaration/xml1n.dcl',
    "$LEGACY_DTD_DIR/basic/xml1.dcl" => 'usr/share/xml/declaration/xml.dcl',
);
# Set this to 0 if you need to compare the merged w3c-dtd-xhtml
# with the old one.
Readonly my $SPARSE_LEGACY => 1;

sanity_check();

# This subroutine generates the debian/xmlcatalogs file - i.e. the
# file registering XML DTD's from the main package w3c-sgml-lib.
# I think something like it but more generic should be in xml-core.
generate_debian_xmlcatalogs();

# This bit is trying to keep w3c-dtd-xhtml as close as possible 
# to its last maintained state whilst leveraging upstream
# input from the W3C.

# legacy src file -> legacy dest file
my %legacy_src = collect_legacy_src();

# legacy src file -> public id
my %public_ids = extract_public_ids(keys %legacy_src);


generate_legacy_stuff(\%legacy_src, \%public_ids);

exit(0);

sub generate_debian_xmlcatalogs {

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
    return;
}

sub collect_legacy_src {
    my %results;
    find(sub {
            return if $_ !~ $LEGACY_MATCH_RE;
            my $dest = $File::Find::name;
            if ($dest =~ m{\A$LEGACY_MATCH_ENT_RE}xms) {
                $dest =~ s{$LEGACY_SRC_DIR/basic}{$LEGACY_ENT_DIR}xms;
            }
            else {
                $dest =~  s{$LEGACY_SRC_DIR}{$LEGACY_DTD_DIR}xms;
            }
            $dest =~ s{/DTD/}{/}xms;
            $results{$File::Find::name} = $dest;
            return;
        },
        $LEGACY_SRC_DIR);
    return %results;
}

sub extract_public_ids {
    my @src_files = @_;
    my %results;
    foreach my $file (@src_files) {
        my $doc = read_file($file);
        if ($doc =~ $PUBLIC_ID_RE) {
            $results{$file} = $1;
        }
        else {
            croak "Could not find public id for $file";
        }
    }
    return %results;
}

sub generate_legacy_stuff {
    open(my $install_fh, '>', 'debian/w3c-dtd-xhtml.install');
    open(my $links_fh, '>', 'debian/w3c-dtd-xhtml.links');
    foreach my $file (keys %LEGACY_DCL_LINKS) {
        my $install = $LEGACY_DCL_LINKS{$file};
        print {$links_fh} "$install $file\n";
    }
    foreach my $file (keys %legacy_src) {
        if ($SPARSE_LEGACY and my $link = find_matching_file($public_ids{$file})) {
            print {$links_fh} "$link $legacy_src{$file}\n";
        }
        else {
            my $install = dirname $legacy_src{$file};
            print {$install_fh} "$file $install\n";
        }
    }
    close $install_fh;
    close $links_fh;
    return;
}

sub find_matching_file {
    my $public_id = shift;
    my $matching_file;
    find(sub {
            return if $matching_file;
            return if not -f $_;
            my $doc = read_file($_);
            if ($doc =~ $PUBLIC_ID_RE and $1 eq $public_id) {
                $matching_file = $File::Find::name;
                $matching_file =~ s{\A$SOURCE_DIR/}{$DEST_DIR/}xms;
            }
            return;
        },
        $SOURCE_DIR
    );
    return $matching_file;
}

sub sanity_check {
    foreach my $file ('debian', $SOURCE_DIR, $LEGACY_SRC_DIR) {
        if (! -d $file) {
            croak "Cannot find directory $file";
        }
    }
    foreach my $file ($CATALOG_XML) {
        if (! -r "$SOURCE_DIR/$file") {
            croak "Cannot read $file";
        }
    }
    return;
}

# Copyright 2010-2012, Nicholas Bamber, Artistic License

