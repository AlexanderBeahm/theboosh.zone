# Makefile.PL

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'HelloPerld',
    VERSION      => '1.0', # Set version directly
    PREREQ_PM    => {
        'DBD::Pg'             => 0,
        'DBI'                 => 0,  # Added for database logging
        'JSON'                => 0,  # Added for JSON file logging
        'Time::Local'         => 0,  # Added for timestamp handling,
        'File::ShareDir'     => 0,  # Added for shared directory handling
        'Mojolicious'         => 0,  # Added for web framework,
        'Mojolicious::Plugin::OpenAPI' => 0, # Added for OpenAPI/Swagger
        'Mojolicious::Plugin::SwaggerUI' => 0, # Added for Swagger UI
        'Crypt::Random'       => 0,  # Added for password salt generation
        'Digest::SHA'         => 0,  # Added for password hashing
    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT      => 'Hello Perl Daemon', # Set abstract directly
       AUTHOR        => 'Alex Beahm <alexanderbeahm@gmail.com>') : ()),
    META_MERGE => {
        resources => {
            repository => 'https://github.com/AlexanderBeahm/hello-perld',
        },
    },
);