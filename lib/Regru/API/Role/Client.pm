package Regru::API::Role::Client;

use v5.10.1;
use strict;
use warnings;
use Moo::Role;
use Carp;
use Regru::API::Response;
use Data::Dumper;

with qw(
    Regru::API::Role::Namespace
    Regru::API::Role::Serializer
    Regru::API::Role::UserAgent
);


has 'namespace' => ( is => 'ro', default => sub {q{}} );
has [ 'username', 'password', 'io_encoding', 'lang', 'debug' ] =>
    ( is => 'ro' );

has 'api_url' => (
    is      => 'ro',
    default => sub { $ENV{REGRU_API_ENDPOINT} || 'https://api.reg.ru/api/regru2/' },
);

sub namespace_methods {
    my $class = shift;

    my $meta = $class->meta;

    foreach my $method ( @{ $class->available_methods } ) {
        $method = lc $method;
        $method =~ s/\s/_/g;

        my $handler = sub {
            my ($self, @args) = @_;
            $self->_api_call($method => @args);
        };

        $meta->add_method($method => $handler);
    }
}

=head1 NAME

    Regru::API::NamespaceHandler - parent handler for all categories handlers.
Does API call and debug logging.

=cut

=head1 New namespace handler creation

First create new namespace handler package:

    package Regru::API::Domain; # must be Regru::API::ucfirst($namespace_name)
    use Modern::Perl;

    use Moo;
    extends 'Regru::API::NamespaceHandler';

    my @methods = qw/nop get_prices get_suggest/; # API calls list

    has '+methods' => (is => 'ro', default => sub { \@methods } );
    has '+namespace' => (default => sub { 'domain' }); # API namespace

    1;

And then add new namespace to @namespaces var in Regru::API

    my @namespaces = qw/user domain/;

=cut

sub _debug_log {
    my $self    = shift;
    my $message = shift;

    warn $message if $self->debug;
}

sub _api_call {
    my $self   = shift;
    my $method = shift;
    my %params = @_;

    my $namespace = $self->namespace;
    my $url       = $self->api_url . $namespace;
    $url .= '/' if $namespace;
    $url .= $method . '?';

    my %post_params = (
        username      => $self->username,
        password      => $self->password,
        output_format => 'json',
        input_format  => 'json'
    );
    $post_params{lang} = $self->lang if defined $self->lang;
    $post_params{io_encoding} = $self->io_encoding
        if defined $self->io_encoding;

    $self->_debug_log(
        "API call: $namespace/$method, params: " . Dumper( \%params ) );

    $self->_debug_log("URI called: $url");

    my $json = $self->serializer->encode( \%params );

    my $response = $self->useragent->post(
        $url,
        [ %post_params, input_data => $json ]
    );

    return Regru::API::Response->new( response => $response );
}

1;