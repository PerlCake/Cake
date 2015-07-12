use 5.010001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Cake',
    VERSION_FROM      => 'lib/Cake.pm',
    ABSTRACT_FROM  => 'lib/Cake.pm',
    EXE_FILES    => ['script/perlcake'],
    PREREQ_PM         => {
        
    },
    LICENSE        => 'perl',
    AUTHOR         => 'Mamod Mehyar <mamod.mehyar@gmail.com>',
    "TEST_REQUIRES" => {
        'CGI::Compile' => 0,
        'CGI::Emulate::PSGI' => 0,
        'HTTP::Request::Common' => 0,
        'Plack' => 0,
        'Plack::Test' => 0,
        'Plack::App::WrapCGI' => 0
    },
    META_MERGE => {
        resources => {
            repository => 'git://github.com/PerlCake/Cake.git',
            bugtracker => 'https://github.com/PerlCake/Cake/issues',
        }
    }
);
