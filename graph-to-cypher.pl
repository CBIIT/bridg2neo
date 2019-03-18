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
