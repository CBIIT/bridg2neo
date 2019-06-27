# NAME

BRIDG2Neo - Create Neo4j graph db from BRIDG XMI

# SYNOPSIS

    $ perl bridg-xmi-to-graph.pl bridg5.2.1.dim.xmi > graph.json
    $ perl bridg-graph-to-cypher.pl graph.json > bridg.cypher
    $ cypher-shell < bridg.cypher

# DESCRIPTION

The scripts `bridg-xmi-to-graph.pl` and `bridg-graph-to-cypher.pl`
extract the [BRIDG](http://bridgmodel.nci.nih.gov/) conceptual model
structure from its [Enterprise
Architect](https://www.sparxsystems.com/products/ea/) XMI/UML
representation ([available
here](https://bridgmodel.nci.nih.gov/download-model/bridg-releases))
into an intermediate JSON representation, then to a set of
[Cypher](https://neo4j.com/docs/cypher-manual/current/) statements.

The statements may be piped into [cypher-shell](https://neo4j.com/docs/operations-manual/3.5/tools/cypher-shell/) to create a Neo4j database.

# DATABASE STRUCTURE

TBD

# AUTHOR

    Mark A. Jensen
    FNCLR
    mark -dot- jensen -at- nih -dot- gov

# LICENSE

This software is Copyright (c) 2019 by FNLCR.

This is free software, licensed under:

    The Apache License, Version 2.0, January 2004
