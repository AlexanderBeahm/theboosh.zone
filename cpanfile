# cpanfile
# Perl dependencies for TheBoosh.Zone

# Database
requires 'DBD::Pg';
requires 'DBI';

# Web Framework
requires 'Mojolicious';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Mojolicious::Plugin::SwaggerUI';

# Cryptography and Security
requires 'Crypt::Random';
requires 'Digest::SHA';

# Image Processing
requires 'Imager';

# File Operations
requires 'File::Path';
requires 'File::Copy';
requires 'File::Basename';
requires 'File::Spec';
requires 'File::ShareDir';

# Data Handling
requires 'JSON';
requires 'MIME::Types';

# Time Utilities
requires 'Time::Local';

# Testing
requires 'Test::More', '>= 1.302';
requires 'Test::Mojo';
requires 'DBD::Mock';
requires 'Test::Exception';
requires 'Test::MockModule';
