#!/bin/sh

. /etc/profile.d/sge.sh

TMPDIR=./BACKUPS/SGE_BACKUP.$SGE_CELL.`date "+%Y%m%d"`
mkdir -p $TMPDIR
cd $TMPDIR

set -C

function log {
    echo "Backing up [$*]"
}

# Backups the queues
for queue in `qconf -sql`; do 
    qconf -sq $queue > queue_$queue
    log queue $queue
done

for hostgroup in `qconf -shgrpl`; do
    qconf -shgrp_tree $hostgroup > hostgroup_$hostgroup
    log hostgroup  $hostgroup
done

#And the default queue
log queue default
qconf -sq > queue_default

log cluster configuration
qconf -sconf > cluster_conf

log scheduler configuration
qconf -ssconf > sched_conf

log complexes
qconf -sc > complexes

log sharetree
qconf -sstree > share_tree

log usersets
qconf -sul > userset_list

log users
qconf -suserl > user_list

log managers
qconf -sm > manager_list

log operators
qconf -so > operator_list

log RQS 
qconf -srqs > resource_quotas

for pe in `qconf -spl`; do 
    log PE $pe
	qconf -sp $pe > pe_$pe
done

for project in `qconf -sprjl`; do 
    log project $project
	qconf -sprj $project > project_$project
done

for su in `qconf -sul`; do 
    log user list $su
	qconf -su $su > ul_$su
done

for e in `qconf -sel`; do 
    log exec host $e
	qconf -se $e > exec_$e
done

log job sequence numbers
cp $SGE_ROOT/$SGE_CELL/spool/qmaster/jobseqnum .
cp $SGE_ROOT/$SGE_CELL/spool/qmaster/arseqnum .

cd -

#gzip -9r $TMPDIR
echo "Making tarball..."
tar cjf ${TMPDIR}.tar.bz2 $TMPDIR -C `dirname $TMPDIR` && rm -rf $TMPDIR
