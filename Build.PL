use Module::Build;

$build = Module::Build->new(
  dist_name => 'BRIDG2Neo',
  dist_abstract => 'Create Neo4j graph db from BRIDG XMI',
  dist_version_from => 'lib/BRIDG2Neo.pm',
  dist_author => 'Mark A. Jensen',
  configure_requires => {
    'Module::Build' => 0,
  },
  requires => {
    'utf8::all' => 0,
    'XML::Twig' => 0,
    'HTML::Entities' => 0,
    'Encode' => 0,
    'Digest::MD5' => 0,
    'Try::Tiny' => 0,
    'JSON' => 2.0,
    'JSON::ize' => 0.104,
    'Neo4j::Cypher::Abstract' => 0.1002,
   }

 );

$build->create_build_script;
