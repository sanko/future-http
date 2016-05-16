package Future::HTTP::Tiny;
use strict;
use Future;
use HTTP::Tiny;
use Moo 2; # or Moo::Lax if you can't have Moo v2
use Filter::signatures;
no warnings 'experimental';
use feature 'signatures';

use vars qw($VERSION);
$VERSION = '0.01';

has ua => (
    is => 'lazy',
    default => sub { HTTP::Tiny->new( %{ $_[0]->{ua_args}} ) }
);

has _ua_args => (
    is => 'ro',
    default => sub { +{} } ,
);

=head1 NAME

Future::HTTP::Tiny - synchronous HTTP client with a Future interface

=head1 DESCRIPTION

This is the default backend. It is chosen if no supported event loop could
be detected. It will execute the requests synchronously as they are
made in C<< ->http_request >> .

=cut

sub BUILDARGS {
    my( $class, %options ) = @_;
    
    return {
        _ua_args => \%options,
    }
}

sub _ae_from_http_tiny( $self, $result ) {
    # Convert the result back to a future
    my( $body )        = delete $result->{content};
    my( $headers )     = delete $result->{headers};
    $headers->{Status} = delete $result->{status};
    $headers->{Reason} = delete $result->{reason};
    $headers->{URL}    = delete $result->{url};
    
    # Only filled with HTTP::Tiny 0.058+!
    if( $result->{redirects}) {
        my $r = $headers;
        for my $http_tiny_result ( reverse @{ $result->{redirects}}) {
            $r->{Redirect} = [ $self->_ae_from_http_tiny( $http_tiny_result ) ];
            $r = $r->{Redirect}->[1]; # point to the new result headers
        };
    };
    
    return ($body, $headers)
};

sub _request($self, $method, $url, %options) {
    
    # Munge the parameters for AnyEvent::HTTP to HTTP::Tiny
    for my $rename (
        ['body'    => 'content'],
        ['body_cb' => 'data_callback']
    ) {
        my( $from, $to ) = @$rename;
        if( $options{ $from }) {
            $options{ $to } = delete $options{ $from };
        };
    };
    
    # Execute the request (synchronously)
    my $result = $self->ua->request(
        $method => $url,
        \%options
    );
    
    my( $body, $headers ) = $self->_ae_from_http_tiny( $result );
    
    if( $headers->{Status} =~ /^2../ ) {
        return Future->done($body, $headers);
    } else {
        return Future->fail($body, $headers);
    }
}

sub http_request($self,$method,$url,%options) {
    $self->_request(
        $method => $url,
        %options
    )
}

sub http_get($self,$url,%options) {
    $self->_request(
        'GET' => $url,
        %options,
    )
}

sub http_head($self,$url,%options) {
    $self->_request(
        'HEAD' => $url,
        %options
    )
}

sub http_post($self,$url,$body,%options) {
    $self->_request(
        'POST' => $url,
        body   => $body,
        %options
    )
}

=head1 METHODS

=head2 C<< Future::HTTP::Tiny->new() >>

    my $ua = Future::HTTP::Tiny->new();

Creates a new instance of the HTTP client.

=head2 C<< $ua->http_get($url, %options) >>

    $ua->http_get('http://example.com/',
        headers => {
            'Accept' => 'text/json',
        },
    )->then(sub {
        my( $body, $headers ) = @_;
        ...
    });

Retrieves the URL and returns the body and headers, like
the function in L<AnyEvent::HTTP>.

=head2 C<< $ua->http_head($url, %options) >>

    $ua->http_head('http://example.com/',
        headers => {
            'Accept' => 'text/json',
        },
    )->then(sub {
        my( $body, $headers ) = @_;
        ...
    });

Retrieves the header of the URL and returns the headers,
like the function in L<AnyEvent::HTTP>.

=head2 C<< $ua->http_post($url, $body, %options) >>

    $ua->http_post('http://example.com/api',
        '{token:"my_json_token"}',
        headers => {
            'Accept' => 'text/json',
        },
    )->then(sub {
        my( $body, $headers ) = @_;
        ...
    });

Posts the content to the URL and returns the body and headers,
like the function in L<AnyEvent::HTTP>.

=head2 C<< $ua->http_request($method, $url, %options) >>

    $ua->http_request('PUT' => 'http://example.com/api',
        headers => {
            'Accept' => 'text/json',
        },
        body    => '{token:"my_json_token"}',
    )->then(sub {
        my( $body, $headers ) = @_;
        ...
    });

Posts the content to the URL and returns the body and headers,
like the function in L<AnyEvent::HTTP>.

=head1 SEE ALSO

L<Future>

L<AnyEvent::HTTP> for the details of the API

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/future-http>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Future-HTTP>
or via mail to L<future-http-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2016 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;