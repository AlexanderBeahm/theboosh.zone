#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# Test that all modules can be loaded without errors

my @modules = qw(
    HelloPerld
    HelloPerld::Server
    HelloPerld::Controller::Health
    HelloPerld::Controller::Articles
    HelloPerld::Controller::Tags
    HelloPerld::Controller::Auth
    HelloPerld::Controller::Media
    HelloPerld::Model::Article
    HelloPerld::Model::Tag
    HelloPerld::Model::Media
    HelloPerld::Database::Postgres
    HelloPerld::Logger::Logger
    HelloPerld::Logger::LoggerFactory
    HelloPerld::Logger::ConsoleLogger
    HelloPerld::Logger::JsonFileLogger
    HelloPerld::Logger::DatabaseLogger
);

plan tests => scalar @modules;

for my $module (@modules) {
    use_ok($module) or BAIL_OUT("Failed to load $module");
}

done_testing();
