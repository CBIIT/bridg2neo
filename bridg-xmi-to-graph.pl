use v5.10;
use utf8::all;
use XML::Twig;
use HTML::Entities;
use Encode qw/encode_utf8/;
use Digest::MD5 qw/md5_hex/;
use Try::Tiny;
use JSON;
use strict;

my $fx = "bridg5.2.1.dim.xmi";

my %elts;
my $t = XML::Twig->new(
  pretty_print => 'indented',
 );
$t->parsefile($fx);

my %nodes;
my %relns;

# BRIDG model itself is encoded in the "uml:Model" branch of the xmi
# 
my $bridg =  $t->root->first_child('uml:Model')->first_child('packagedElement');
# collect all uml entities by id
my %entities;

# get primitive types
for my $typ ($t->descendants('[@xmi:type="uml:PrimitiveType"]')) {
  $entities{$typ->att('xmi:id')} = $typ;
}

# BRIDG "subdomains" are expressed as packagedElement(s) of
# xmi:type "uml:Package"

my @subdomains = $bridg->children('packagedElement');
my $split_name = sub { join(" ", ($_[0] =~ /((?:^|[[:upper:]])(?:[[:upper:]]+(?:(?=[[:upper:]])|$)|[[:lower:]]+))/g)) };

foreach my $subd (@subdomains) {
  my $subd_id = $subd->att('xmi:id');
  $entities{$subd_id} = $subd;
  $nodes{$subd_id} = {
    id => $subd_id,
    type => $subd->att('xmi:type'),
    name => $subd->att('name')
   };
  # Find all the BRIDG classes
  for my $c ($subd->children('[@xmi:type="uml:Class"]')) {
    my $c_id =$c->att('xmi:id');
    $entities{$c_id} = $c;
    unless ($c->att('name') && length($c->att('name'))) {
      warn "Class with id '$c_id' has no 'name' attribute. Skipping...";
      next;
    }

    $nodes{$c_id} = { id => $c_id, type => $c->att('xmi:type'), name => $c->att('name'),
		     _split_name => $split_name->($c->att('name'))};
    push @{$relns{'contains_class'}{instances}}, { type => 'contains_class', src => $subd_id, dst => $c_id };
    # Find all the properties for the class
    for my $p ($c->children('[@xmi:type="uml:Property"]')) {
      my $p_id = $p->att('xmi:id');
      my $p_type = $p->first_child('type')->att('xmi:idref');
      if ($entities{$p_type}) {
	$p_type = decode_entities($entities{$p_type}->att('name')) if ($p_type);
      }
      else {
	warn "No primitive type corresponding to id '$p_type'";
      }
      unless ($p->att('name')) {
	warn "Property defined in element:\n".$p->outer_xml." has no name defined; skipping...";
	next;
      }
	
      unless ($p_type) {
	warn "Property defined in element:\n".$p->outer_xml." has no data type defined"
      }
      $entities{$p_id} = $p;
      $nodes{$p_id} = {
	id => $p_id, type => $p->att('xmi:type'),
	name => $p->att('name'),
	_split_name => $split_name->($p->att('name')),
	$p_type ? (data_type => $p_type) : (),
	$p->att('aggregation') ? (aggregation => $p->att('aggregation')) : () };
      push @{$relns{'has_property'}{instances}}, { type => 'has_property', src =>$c_id, dst => $p_id, src_card => [0,-1], dst_card => [0,-1] };
    }
    # if the class has an "is_a" (inheritance) relationship with other
    # classes, these are expressed in an element with xmi:type
    # "uml:Generalization"
    # the "general" attr has parent class' EAID
    for my $g ($c->children('[@xmi:type="uml:Generalization"]')) {
      my $g_id = $g->att('xmi:id'); 
      $entities{$g_id} = $g;
      # create a node that represents the Generalization entity
      $nodes{$g_id} = { id => $g_id, type => $g->att('xmi:type'),
			  generalizes => $c_id,
			  general => $g->att('general')};
      # create relationship that is an instance of the Generalization entity
      push @{$relns{'is_a'}{instances}}, { type => 'is_a', src => $c_id, dst => $g->att('general'), src_card => [0,-1], dst_card => [1,1],
					   gnl_id => $g_id };
    }
  }
  # Capture the other relationships - associations - among the class and
  # other classes
  for my $a ($subd->children('[@xmi:type="uml:Association"]')) {
    my $a_id = $a->att('xmi:id');
    my $a_name = $a->att('name');
    $a_name =~ s/ /_/g;
    $entities{$a_id} = $a;
    # create a node that represents the Association entity
    $nodes{$a_id} = { id => $a_id, type => $a->att('xmi:type'),
			name => $a_name };
    # create relationships which are instances of the Association entity
    my ($end1, $end2) = $a->children('ownedEnd');
    # note the ownedEnds of the relationship are not ordered "src", "dst"
    # use the text of the ownedEnd id :( to determine
    my ($src, $dst);
    unless ($end1 && $end2) {
      warn "'$a_name':$a_id - one or both ends not defined; skipping..." unless $src;
      next;
    }
    ($end1->att('xmi:id') =~ /src/) && ($src = $end1);
    ($end1->att('xmi:id') =~ /dst/) && ($dst = $end1);
    ($end2->att('xmi:id') =~ /src/) && ($src = $end2);
    ($end2->att('xmi:id') =~ /dst/) && ($dst = $end2);
    unless ($src && $dst) {
      warn "'$a_name':$a_id - src end not defined; skipping..." unless $src;
      warn "'$a_name':$a_id - dst end not defined; skipping..." unless $dst;
      next;
    }
    warn "'$a_name':$a_id first ownedEnd not 'src'" unless $src->att('xmi:id') =~ /src/;
    warn "'$a_name':$a_id second ownedEnd not 'dst'" unless $dst->att('xmi:id') =~ /dst/;
    # src_card and dst_card capture the cardinality at the respective end
    # of the relns
    # card = (lowerValue, upperValue)
    # (0,1) - 0 or 1 item
    # (1,1) - exactly one item
    # (1,-1) - 1 or more items
    # (0, -1) - 0 or more items
    push @{$relns{$a_name}{instances}}, {
      type => $a_name,
      src => $src->first_child('type')->att('xmi:idref'),
      dst => $dst->first_child('type')->att('xmi:idref'),
      src_role => $src->att('name'),
      dst_role => $dst->att('name'),
      src_card => [ 0+$src->first_child('lowerValue')->att('value'),
		    0+$src->first_child('upperValue')->att('value') ],
      dst_card => [ 0+$dst->first_child('lowerValue')->att('value'),
		    0+$dst->first_child('upperValue')->att('value') ],
    }
  }
}

# name the Generalizations
for ( grep { $_->{type} =~ /Generalization/} values %nodes ) {
  $_->{name} = join(':is_a:',
		    $entities{$_->{generalizes}}->att('name'),
		    $entities{$_->{general}}->att('name'));
}

# External models and mappings

my @external_models = grep {
  $_->att('xmi:type') eq 'uml:Stereotype' and
    $_->att('name') =~ /^Map/ } $t->root->descendants;

my @maps = grep { $_->tag =~ /^thecustomprofile:Map/ } $t->root->descendants;

my (%x_nodes, %x_relns);

for my $m (@external_models) {
  my ($name) = $m->att('name') =~ /^Map.(.*)$/;
  $x_nodes{$m->att('name')} //= {id => $m->att('name'), name => $name, type => $m->att('xmi:type')};
}

for my $r (@maps) {
  my $atts = $r->atts;
  my ($bid, $mid);
  my ($content_key) = $r->tag =~ /^thecustomprofile:(.*)/;
  if (!defined $atts->{$content_key}) {
    warn "No content for mapping:\n".$r->outer_xml."(content key: $content_key) Skipping...";
    next;
  }
  $mid = $atts->{__EAStereoName};
  my ($base_type) = grep /^base_/, keys %$atts;
  $bid = $atts->{$base_type};
  unless ($bid) {
    warn "No Class, Property, Association or Generalization base attribute in mapping:\n".$r->outer_xml."Skipping...";
    next;
  }
  my $oid = md5_hex(encode_utf8($content_key."=".$atts->{$content_key}));
  my ($type) = $base_type =~ /^base_(.*)/;
  $x_nodes{$oid} //= { type => "X$type",
		   name => $atts->{$content_key},
		   id => $oid };
  unless ($entities{$bid}) {
    warn "BRIDG $type entity $bid not captured earlier for mapping $mid";
  }
  $x_relns{$oid.$mid} //= { type => 'from_model', src => $oid, dst => $mid };
  $x_relns{$bid.$oid} //= { type => 'maps_to', src => $bid, dst => $oid,
			    src_card => [0,-1], dst_card => [0, -1] };
}

# Views
my (%v_nodes,%v_relns);

my @diagrams = $t->root->descendants('diagram');
for my $d (@diagrams) {
  my $vid = $d->att('xmi:id');
  my $view_name = $d->first_child('properties')->att('name');
  my $view_doc = $d->first_child('properties')->att('documentation');
  my @classes;
  for my $e ($d->first_child('elements')->children) {
    my $ent = $entities{$e->att('subject')};
    next unless $ent;
    if ($ent->att('xmi:type') &&
	  ($ent->att('xmi:type') eq 'uml:Class') &&
	  $ent->att('name')
	 ) {
      push @classes, $e->att('subject');
    }
  }
  if (@classes) {
    $v_nodes{$vid} //= { id => $vid, type => 'View',
			 name => $view_name };
    $v_nodes{$vid}{doc} = $view_doc if $view_doc;
    for my $c (@classes) {
      $v_relns{$vid.$c} //= { type => 'contains_class', dst => $c,
		       src => $vid};
    }
  }
}

# Comments
my (%cmt_nodes, %cmt_relns);

my @comments = $bridg->descendants('[@xmi:type="uml:Comment"]');
for my $c (@comments) {
  my $cid = $c->att('xmi:id');
  unless ($c->att('body')) {
    warn "Comment object '$cid' has no comment body. Skipping...";
    next;
  }
  my $c_body = decode_entities($c->att('body')); # comment content
  my $c_anelt;
  if (my $e = $c->first_child('annotatedElement')) {
    unless ($c_anelt = $e->att('xmi:idref')) {
      warn "Comment object '$cid' annotatedElement has no idref. Skipping...";
      next;
    }
    unless (defined $entities{$c_anelt}) {
      warn "annotatedElement '$c_anelt' for comment object '$cid' is unknown. Skipping...";
      next;
    }
  }
  else {
    warn "Comment object '$cid' has no <annotatedElement>. Skipping...";
    next;
  }


  $cmt_nodes{$cid} //= { id => $cid, type => 'Comment',
			 body => $c_body };
  $cmt_relns{$cid.$c_anelt} //= { type => 'comments_on', dst => $c_anelt,
				    src => $cid };
}

# Class and Property documentation

my (%doc_nodes, %doc_relns);

my @docs = grep { $_->parent->att('xmi:type') eq 'uml:Class' } $t->root->descendants('properties[@documentation]');

push @docs, grep { $_->parent->tag eq 'attribute' } $t->root->descendants('documentation');

for my $d (@docs) {
  my $idref = $d->parent->att('xmi:idref');
  my $did = "D_".$idref;
  my $d_body = decode_entities($d->att('documentation')) ||
    decode_entities($d->att('value'));
  unless ( $entities{$idref} ) {
    warn "Doc text refers to unknown class with id '$idref'. Skipping...";
    next;
  }
  $doc_nodes{$did} //= { id => $did, type => 'Documentation',
			 body => $d_body };
  $doc_relns{$did.$idref} //= { type => 'documents', src => $did,
				dst => $idref };
}

$DB::single=1;

# Emit a large JSON file of nodes and edges
# { "nodes" : [ <array of node objects> ],
#   "relationships" : [ <array of relationship objects> ] }
#
# node objects: { id: <id>, type: <label>, name: <name>, .. }
# reln objects: { src: <node-id>, dst: <node-id>, type: <relationship_name>,
#                 ... }

# create node csvs; node labels - uml types
my (@Nodes,@Relationships);

push @Nodes, values %nodes, values %x_nodes, values %v_nodes,
  values %cmt_nodes, values %doc_nodes;

for my $typ (keys %relns) {
  push @Relationships, @{$relns{$typ}{instances}};
}

push @Relationships, values %x_relns, values %v_relns,
  values %cmt_relns, values %doc_relns;

my $j = JSON->new()->pretty(1);

print $j->encode( { Nodes => \@Nodes,
		    Relationships => \@Relationships } );

1;

