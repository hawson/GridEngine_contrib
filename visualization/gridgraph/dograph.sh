#!/bin/sh
#
#    dograph.sh
#
#    Copyright (c) 2011 - Gary Smith
#
#    This file is part of GridGraph.
#
#    GridGraph is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    GridGraph is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with GridGraph.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Pretty obvious script to constantly update the qstat.xml and qhost.xml files for graphviz.py
# I would suggest running this on the sge master server.
# Sticks the PNG in my public_html directory so my http://website.com/~mylogin/gridgraph.html page can find it.

GGHOME=/where/ever/you/put/the/python/script

while true
do
    qstat -f -u "*" -ne -xml > $GGHOME/qstat.xml
    qhost -xml > $GGHOME/qhost.xml
    $GGHOME/gridgraph.py > $GGHOME/gridgraph
    neato -Tpng -O $GGHOME/gridgraph
    cp $GGHOME/gridgraph.png $HOME/public_html
    sleep 7
done
