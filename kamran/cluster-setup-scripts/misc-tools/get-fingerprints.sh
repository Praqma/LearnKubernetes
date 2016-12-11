#!/bin/bash
# Summary: Gets the fingerprints of the nodes, as listed in the hosts file in the parent directory.


for node in $(grep ^10.240.0  ../hosts | grep -v \# | awk '{print $1,$2}') ; do  
  # This produces X lines of output where X corresponds to the number of enabled hosts in the hosts file.
  # But since there is a comma (,) in awk command the two variables (IP and FQDN) are separated by space,
  # which are treated as two separate values by the for command. thus this loop runs for (2 times X) times,
  # which we use to remove all possible lines from the known_hosts file - which is safe.
 
  echo "Removing previous entries of the node $node from ~/.ssh/known_hosts"
  echo "--------------------------------------------------------------------"
  sed -i '/${node}/d' /home/kamran/.ssh/known_hosts
done

# At this point, we are done removing the existing entries, so now we can add proper entries in the known_hosts file.
# Run loop one more time, but this time use comma in awk in the output, to concatenate IP and FQDN, like (IP,FQDN).
# This is then used by ssh-keyscan.
  
for node in $(grep ^10.240.0  ../hosts | grep -v \# | awk '{print $1 "," $2}') ; do  
  # This produces X lines of output where X corresponds to the number of enabled hosts in the hosts file.
  # But since there is a comma (,) in awk command the two variables (IP and FQDN) are separated by space,
  # which are treated as two separate values by the for command. thus this loop runs for (2 times X) times,
  # which we use to remove all possible lines from the known_hosts file - which is safe.
 
  echo "Adding fingerprint in ~/.ssh/known_hosts for node \"$node\"  "
  echo "-------------------------------------------------------------------------------"
  # sed -i '/${node}/d' /home/kamran/.ssh/known_hosts
done


