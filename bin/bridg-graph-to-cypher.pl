use JSON::ize;
use v5.10;
use Neo4j::Cypher::Abstract qw/cypher ptn/;
use strict;

# convert bridg->graph JSON nodes and relns to cypher
# create queries

my $fn = shift();
unless (-e $fn) {
  die "Can't find file '$fn'";
}

my $j = J($fn) or die "Can't open '$fn' as JSON";

1;

my @labels;
for my $n (@{$j->{Nodes}}) {
  if (grep(/^name$/, keys %$n) && !defined $n->{name}) {
    warn "Node $$n{id} has name key but value not defined; skipping...";
    next;
  }
  if ($n->{name} && $n->{name} =~ /\$/) {
    $n->{name} =~ s/\$/%24/g;
  }
  my $label = $n->{type};
  $label =~ s/^uml://;
  push @labels, $label;
  say cypher->create(ptn->N(":$label", $n)).";";
  1;
}

for (@labels) {
  say cypher->create_index($_,'id').";";
  say cypher->create_index($_,'name').";";
}

# fulltext indexing -- note below only valid for Neo4j 3.5+
# for the name: property, split the node name camelcase into separate words
# and index the resulting property: this is the right regexp for the split:
# /((?:^|[[:upper:]])(?:[[:upper:]]+(?:(?=[[:upper:]])|$)|[[:lower:]]*))/g

# for Class, Property - index on camelcase split of name
#

say 'CALL db.index.fulltext.createNodeIndex("ftClassPropertyIndex",["Class","Property"], ["_split_name"]);' ;

# for View - index directly on name
say 'CALL db.index.fulltext.createNodeIndex("ftViewIndex",["View"], ["name"]);';

# for Doc - index directly on body
say 'CALL db.index.fulltext.createNodeIndex("ftDocuIndex",["Documentation"], ["body"]);';

# also want to index XClass and XProperty -- determine how to split

for my $r (@{$j->{Relationships}}) {
  my $src = delete ${$r}{'src'};
  my $dst = delete ${$r}{'dst'};
  my $type = delete ${$r}{'type'};
  for (keys %$r) {
    $r->{$_} = J($r->{$_}) if ref $r->{$_};
  }
  say cypher->match(
    ptn->C(ptn->N("a",{id=>$src}),ptn->N("b",{id=>$dst}))
   )->create(
     ptn('[[]')->N("a")->R(":$type>", (keys %$r)?$r:())->N("b")
    ).";"; 
}

# add an UrClass (top level Class) object, so that every Class is_a UrClass
say cypher->create( ptn->N("u:Class",{name => "UrClass", id => "UrClass"}) ).";";
say cypher->match(
  ptn->C(ptn->N("u:Class",{ id=>"UrClass" }), ptn->N("c:Class") )
 )->
  where( { -not => ptn->N("c")->R(":is_a>")->N() } )->
  create( ptn->N("c")->R(":is_a>")->N("u") ).";";
say cypher->match( ptn->N("u:Class", {name => "UrClass"})->R("r>")->N("u") )->delete("r").";";





