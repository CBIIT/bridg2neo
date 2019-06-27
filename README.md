# Neo4j representation of BRIDG

[BRIDG](https://bridgmodel.nci.nih.gov/) is a conceptual model for linking
high-level concepts across multiple healthcare domain vocabularies.

BRIDG is represented in a computable XMI format, but that format is
proprietary, and contains a large amount of information that is necessary
only for the graphical rendition of the model and various views in the context
of the proprietary software.

The [bridg-xmi-to-graph.pl](./bridg-xmi-to-graph.pl) script here
scrapes the public BRIDG XMI file for

* relevant classes, properties, associations and generalizations,

* class groupings expressed as "Subdomains" and "Views", and

* class, property, association and generalization mappings to external
datamodels.

These structures are expressed as simple Node and Relationship objects in
an output JSON file.

The JSON file can then be parsed and converted into Neo4j Cypher
language CREATE statments by [graph-to-cypher.pl](./graph-to-cypher.pl).

# Installation

The perl scripts can be installed (and the relevant dependencies also) as
follows:

`$ perl Build.PL
 $ ./Build installdeps
 $ ./Build install
`
 
  

