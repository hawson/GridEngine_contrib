#!/usr/bin/env python
#
#    gridgraph.py
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
import os,datetime
from xml.etree import ElementTree as ET

# Determine how "hot" the node is and give it a color
def getTemp(node,hosts,maxslots):
	# Give each cluster node a temperature color similar to MacAdam's chromaticity scale
	# http://en.wikipedia.org/wiki/CIE_1960_color_space
	# low load starts as dull red and heats up through orange, yellow, cyan, blue, etc.
	clrRng = [ "#FF0006", "#FF0B05", "#FF1603", "#FE2102", "#FE2C00", "#FE2C00", "#FE5103", "#FD7606", "#FD9A08", "#FCBF0B", "#FCBF0B", "#FDC92C", "#FDD44D", "#FEDE6E", "#FEE88F", "#FEE88F", "#FEECA0", "#FFF1B1", "#FFF5C2", "#FFF9D3", "#FFF9D3", "#FFFADE", "#FFFAE9", "#FFFBF4", "#FFFBFF", "#FFFBFF", "#FDFAFF", "#FBF9FF", "#F8F8FF", "#F6F7FF", "#F6F7FF", "#F1F4FE", "#EDF1FE", "#E8EDFD", "#E3EAFC", "#E3EAFC", "#DDEAFC", "#D7EAFC", "#D0EAFB", "#CAEAFB", "#CAEAFB", "#C9E5FC", "#C9E0FD", "#C8DBFD", "#C7D6FE", "#C7D6FE", "#C5D6FE", "#C3D6FF", "#C0D5FF", "#BED5FF", "#BED5FF", "#B1CBFF", "#A5C1FF", "#98B7FF", "#8BADFF" ]

	for host in hosts:
		fqdn = node+".bos1.vrtx.com"
		name = host.get('name')
		if name == fqdn:
			hostvalues = host.findall("hostvalue")
			for value in hostvalues:
				if value.get('name') == "load_avg":
					load_avg = float(value.text)

	# load of 1.0 is really equal to unix load of max slots for the execution host
	load = load_avg / maxslots

	# color range will top out at greater than 5.5x maxslots
	if load < 5.5:
		x = int(load * 10)
	else:
		x = 54

	return clrRng[x]

# Process the jobs
def doJobSlots(joblist,queue,nodename,qslots,hosts):
	# slots used by the job determine edge thickness
	slots = 2 * int(joblist.findtext("slots"))

	# change the edge look depending on the state of the job
	state = joblist.findtext("state")
	if state == "r":
		style="solid"
	elif state == "s" or state == "S" or state == "T" or state == "w":
		style="dashed"
	else:
		style="dotted"

	# change the edge and job color depending on which queue it is in
	# edit this as desired to fit your queues
	if queue == "high.q":
		color="#DF00FF"
	elif queue == "all.q":
		color="#8C92AC"
	elif queue == "low.q":
		color="#534B4F"
	else:
		color="#003399"

	temperature = getTemp(nodename,hosts,float(qslots))

	# My cluster nodes are named hpcnode1a, hpcnode1b, hpcnode2a, etc.
	# I only care about displaying the number/alpha of the node which looks nicer in the graph
	# The exception is for a few servers that have non-hpcnode names.
	if nodename[:7] == "hpcnode":
		label = nodename[7:]
	else:
		label = nodename

	# Make a graph node for each job and each cluster node and create the edge connections
	# showing which jobs run on which cluster nodes. Unfortunately, node names must start
	jobNumber = joblist.findtext("JB_job_number")
	jobOwner = joblist.findtext("JB_owner")

	# Unfortunately, node names must start with a letter, so we have to add the "J" to the
	# beginning of job node names.
	print "\tJ"+jobNumber+" [style=filled,penwidth=8,label=\""+jobNumber+"\\n"+jobOwner+"\",shape=box,color=\""+color+"\",fontcolor=\"white\"];"
	print "\t"+nodename+" [style=filled,penwidth=4,label=\""+label+"\",shape=polygon,regular=\"true\",sides=\""+qslots+"\",fillcolor=\""+temperature+"\",color=\"white\"];"
	print "\tJ"+jobNumber+" -- "+nodename+" [penwidth=\""+str(slots)+"\",len=1.0,color=\""+color+"\"];"

# Process the XML and work through each queue's jobs
def doQueues(queue,hosts):
	queueNodeName = queue.findtext("name")
	queueName = queueNodeName.split("@")[0]
	nodeName = queueNodeName.split("@")[1]
	# Strip off domain name from any cluster node name
	nodeName = nodeName.split(".")[0]
	queueSlots = queue.findtext("slots_total")
	for jobList in queue.findall("job_list"):
		doJobSlots(jobList,queueName,nodeName,queueSlots,hosts)

def main():
	# expect to see the XML output from `qstat -f -u "*" -ne -xml > qstat.xml`
	xml_file = os.path.abspath(__file__)
	xml_file = os.path.dirname(xml_file)
	xml_file = os.path.join(xml_file, "qstat.xml")

	try:
		qtree = ET.parse(xml_file)
	except Exception, inst:
		print "Unexpected error opening %s: %s" % (xml_file, inst)
		return

	# expect to see the XML output from `qhost -xml > qhost.xml`
	xml_file = os.path.abspath(__file__)
	xml_file = os.path.dirname(xml_file)
	xml_file = os.path.join(xml_file, "qhost.xml")

	try:
		htree = ET.parse(xml_file)
	except Exception, inst:
		print "Unexpected error opening %s: %s" % (xml_file, inst)
		return

	# These are various parameters for GraphViz to adjust how the graph is drawn.
	# See http://graphviz.org/Documentation.php for details and adjust as desired.
	print "graph G {"
	print "\tstart=\"regular\";"
	print "\toutputorder=\"edgesfirst\";"
	print "\tmodel=\"mds\";"
	print "\tsep=\"0.7\";"
	print "\tesep=\"0.5\";"
	print "\tbgcolor=\"black\";"
	print "\tsplines=\"true\";"
	print "\toverlap=\"false\";"
	print "\tsize=\"13.0,9.75\";"

	# Print the time at the top of the graph so we know if it is updating properly.
	now = datetime.datetime.today()
	print "\tlabelloc=\"t\";"
	print "\tlabel=\"HPC Cluster Activity - "+now.ctime()+"\";"
	print "\tfontcolor=white;"
	print "\tfontsize=24.0;"

	qroot = qtree.getroot()
	hroot = htree.getroot()
	queue_info = qroot.find("queue_info")
	hosts = hroot.findall("host")
	for QueueList in queue_info.findall("Queue-List"):
		doQueues(QueueList,hosts)
	print "}"

if __name__ == "__main__":
	main()

