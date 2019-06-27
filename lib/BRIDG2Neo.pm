package BRIDG2Neo;
use strict;

our $VERSION = '0.1';

=head1 NAME

BRIDG2Neo - Create Neo4j graph db from BRIDG XMI

=head1 SYNOPSIS

  $ perl bridg-xmi-to-graph.pl bridg5.2.1.dim.xmi > graph.json
  $ perl bridg-graph-to-cypher.pl graph.json > bridg.cypher
  $ cypher-shell < bridg.cypher

=head1 DESCRIPTION

The scripts C<bridg-xmi-to-graph.pl> and C<bridg-graph-to-cypher.pl>
extract the L<BRIDG|http://bridgmodel.nci.nih.gov/> conceptual model
structure from its L<Enterprise
Architect|https://www.sparxsystems.com/products/ea/> XMI/UML
representation (L<available
here|https://bridgmodel.nci.nih.gov/download-model/bridg-releases>)
into an intermediate JSON representation, then to a set of
L<Cypher|https://neo4j.com/docs/cypher-manual/current/> statements.

The statements may be piped into L<cypher-shell|https://neo4j.com/docs/operations-manual/3.5/tools/cypher-shell/> to create a Neo4j database.

=head1 DATABASE STRUCTURE

TBD

=head1 AUTHOR

  Mark A. Jensen
  FNCLR
  mark -dot- jensen -at- nih -dot- gov

=head1 LICENSE

This software is Copyright (c) 2019 by FNLCR.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
