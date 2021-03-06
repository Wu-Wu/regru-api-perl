use strict;
use warnings;
use Test::More tests => 4;
use t::lib::NamespaceClient;
use t::lib::Connection;

my $api_avail;

subtest 'Generic behaviour' => sub {
    plan tests => 2;

    my @methods = qw(
        nop
        create
        get_statistics
        get_balance
        refill_balance
    );

    my $client = t::lib::NamespaceClient->user;

    isa_ok $client, 'Regru::API::User';
    can_ok $client, @methods;
};

subtest 'Unautheticated requests' => sub {
    my $client = t::lib::NamespaceClient->user;

    $api_avail ||= t::lib::Connection->check($client->endpoint);

    unless ($api_avail) {
        diag 'Some tests were skipped. No connection to API endpoint.';
        plan skip_all => '.';
    }
    else {
        plan tests => 3;
    }

    # reset std test/test credentials
    $client->username(undef);
    $client->password(undef);

    my $resp = $client->refill_balance;

    ok !$resp->is_success,                      'Request success';
    is $resp->error_text, 'No username given',  'Got correct error_text';
    is $resp->error_code, 'NO_USERNAME',        'Got correct error_code';
};

subtest 'Namespace methods (nop)' => sub {
    my $client = t::lib::NamespaceClient->user;
    my $resp;

    $api_avail ||= t::lib::Connection->check($client->endpoint);

    unless ($api_avail) {
        diag 'Some tests were skipped. No connection to API endpoint.';
        plan skip_all => '.';
    }
    else {
        plan tests => 1;
    }

    # /user/nop
    $resp = $client->nop;
    ok $resp->is_success,                                   'nop() success';
};

subtest 'Namespace methods (overall)' => sub {
    unless ($ENV{REGRU_API_OVERALL_TESTING}) {
        diag 'Some tests were skipped. Set the REGRU_API_OVERALL_TESTING to execute them.';
        plan skip_all => '.';
    }

    my $client = t::lib::NamespaceClient->user;
    my $resp;

    $api_avail ||= t::lib::Connection->check($client->endpoint);

    unless ($api_avail) {
        diag 'Some tests were skipped. No connection to API endpoint.';
        plan skip_all => '.';
    }
    else {
        plan tests => 10;
    }

    # /user/get_statistics
    $resp = $client->get_statistics;
    ok $resp->is_success,                                   'get_statistics() success';
    is $resp->get('balance_total'), 100,                    'get_statistics() got correct balance total value';

    # /user/get_balance
    $resp = $client->get_balance;
    ok $resp->is_success,                                   'get_balance() success';
    is $resp->get('prepay'), 1000,                          'get_balance() got correct prepay value';
    is $resp->get('currency'), 'RUR',                       'get_balance() got correct currency code';

    $resp = $client->get_balance(currency => 'UAH');
    is $resp->get('currency'), 'UAH',                       'get_balance() UAH currency okay';

    # /user/refill_balance
    my $refill_balance_answer = {
        currency => 'RUR',
        payment => 100,
        pay_type => 'WM',
        wm_invid => 12345678,
        total_payment => 100,
        wmid => 123456789012,
    };

    $resp = $client->refill_balance(
        pay_type => 'WM',
        wmid     => 123456789012,
        currency => 'RUR',
        amount   => 100
    );
    ok $resp->is_success,                                   'refill_balance() success';
    is_deeply $resp->answer, $refill_balance_answer,        'refill_balance() answer as expected';

    # /user/create
    $resp = $client->create(
        user_login        => 'othertest',
        user_password     => 'xxxx',
        user_email        => 'test@test.ru',
        user_country_code => 'ru'
    );
    ok !$resp->is_success,                                  'create() failed';
    is $resp->error_code, 'INVALID_CONTACTS',               'create() got correct error_code';
};

1;
