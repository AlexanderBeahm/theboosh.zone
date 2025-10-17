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
        'Imager'              => 0,  # Added for image processing
        'File::Path'          => 0,  # Added for directory creation
        'File::Copy'          => 0,  # Added for file operations
        'File::Basename'      => 0,  # Added for filename parsing
        'MIME::Types'         => 0,  # Added for MIME type detection
        'Test::More'          => '1.302',  # Core testing framework
        'Test::Mojo'          => 0,  # Mojolicious testing
        'DBD::Mock'           => 0,  # Mock database driver
        'Test::Exception'     => 0,  # Exception testing
        'Test::MockModule'    => 0,  # Module mocking
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
