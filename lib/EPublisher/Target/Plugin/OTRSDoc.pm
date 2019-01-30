package EPublisher::Target::Plugin::OTRSDoc;

# ABSTRACT: Create HTML version of OTRS documentation

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);
use HTML::Template::Compiled;
use Pod::Simple::XHTML;

use EPublisher;
use EPublisher::Target::Base;
use parent qw(EPublisher::Target::Base);

our $VERSION = 1.01;

sub deploy {
    my ($self, $sources) = @_;
    
    my @pods = @{ $sources || [] };
    if ( !@pods ) {
        @pods = @{ $self->_config->{source} || [] };
    }

    return if !@pods;
    
    my $encoding = $self->_config->{encoding} || 'utf-8';
    my $base_url = $self->_config->{base_url} || '';
    my $version  = 0;
    
    my @TOC = map{
        (my $name = $_->{title}) =~ s/::/_/g; 
        { target => join( '/', $base_url, lc( $name ) . '.html'), name => $_->{title} };
    } @pods;
    
    my $output = $self->_config->{output};
    make_path $output if $output && !-d $output;
    
    for my $pod ( @pods ) {    
        my $parser = Pod::Simple::XHTML->new;
        $parser->index(0);
        
        (my $name = $pod->{title}) =~ s/::/_/g; 
                
        $parser->output_string( \my $xhtml );
        $parser->parse_string_document( $pod->{pod} );

        my $template = $self->_config->{template};
        my %opts = $template ?
            ( filename  => $template ) :
            ( scalarref => \do { local $/; <DATA> } );
        
        my $tmpl = HTML::Template::Compiled->new(
            %opts,
        );
        
        $xhtml =~ s{</body>}{};
        $xhtml =~ s{</html>}{};
        
        $tmpl->param(
            TOC  => \@TOC,
            Body => $xhtml,
        );
        
        my $fh = *STDOUT;

        if ( $output ) {
            open $fh, '>', File::Spec->catfile( $output, lc $name . '.html' );
            binmode $fh, ":encoding($encoding)";
        }

        print $fh $tmpl->output;

        if ( $output ) {
            close $fh;
        }
    }
}

## -------------------------------------------------------------------------- ##
## Change behavour of Pod::Simple::XHTML
## -------------------------------------------------------------------------- ##

{
    no warnings 'redefine';
    
    *Pod::Simple::XHTML::idify = sub {
        my ($self, $t, $not_unique) = @_;
        for ($t) {
            s/<[^>]+>//g;            # Strip HTML.
            s/&[^;]+;//g;            # Strip entities.
            s/^([^a-zA-Z]+)$/pod$1/; # Prepend "pod" if no valid chars.
            s/^[^a-zA-Z]+//;         # First char must be a letter.
            s/[^-a-zA-Z0-9_]+/-/g; # All other chars must be valid.
        }
        return $t if $not_unique;
        my $i = '';
        $i++ while $self->{ids}{"$t$i"}++;
        return "$t$i";
    };
    
    *Pod::Simple::XHTML::start_Verbatim = sub {};
    
    *Pod::Simple::XHTML::end_Verbatim = sub {
        my ($self) = @_;
        
        $self->{scratch} =~ s{  }{ &nbsp;}g;
        $self->{scratch} =~ s{\n}{<br />}g;
        #$self->{scratch} =  '<div class="code">' . $self->{scratch} . '</div>';
        $self->{scratch} =  '<p><code class="code">' . $self->{scratch} . '</code></p>';
        
        $self->emit;
    };

    *Pod::Simple::XHTML::start_L  = sub {

        # The main code is taken from Pod::Simple::XHTML.
        my ( $self, $flags ) = @_;
        my ( $type, $to, $section ) = @{$flags}{ 'type', 'to', 'section' };
        my $url =
            $type eq 'url' ? $to
          : $type eq 'pod' ? $self->resolve_pod_page_link( $to, $section )
          : $type eq 'man' ? $self->resolve_man_page_link( $to, $section )
          :                  undef;

        # This is the new/overridden section.
        if ( defined $url ) {
            $url = $self->encode_entities( $url );
        }

        # If it's an unknown type, use an attribute-less <a> like HTML.pm.
        $self->{'scratch'} .= '<a' . ( $url ? ' href="' . $url . '">' : '>' );
    };
    
    *Pod::Simple::XHTML::start_Document = sub {
        my ($self) = @_;

        #my $xhtml_headers =
        #    qq{<?xml version="1.0" encoding="UTF-8"?>\n}
        #  . qq{<!DOCTYPE html\n}
        #  . qq{ PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"\n}
        #  . qq{ "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n} . qq{\n}
        #  . qq{<html xmlns="http://www.w3.org/1999/xhtml">\n}
        #  . qq{<head>\n}
        #  . qq{<title></title>\n}
        #  . qq{<meta http-equiv="Content-Type" }
        #  . qq{content="text/html; charset=utf-8"/>\n}
        #  . qq{<link rel="stylesheet" href="../styles/style.css" }
        #  . qq{type="text/css"/>\n}
        #  . qq{</head>\n} . qq{\n}
        #  . qq{<body>\n};


        #$self->{'scratch'} .= $xhtml_headers;
        $self->emit('nowrap');
    };
}

1;

=encoding utf8

=head1 SYNOPSIS

  use EPublisher::Target;
  my $EPub = EPublisher::Target->new( { type => 'OTRSDoc' } );
  $EPub->deploy;

=head1 METHODS

=head2 deploy

creates the output.

  $EPub->deploy;

=head1 YAML SPEC

  EPubTest:
    source:
      #...
    target:
      type: ÓTRSDoc

=head1 TODO

=head2 document methods

=cut

__DATA__
<%loop TOC %>
  <a href="<%= target %>"><%= name %></a>
<%/loop %>
<%= Body %>
