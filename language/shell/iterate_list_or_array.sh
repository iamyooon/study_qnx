#!/bin/sh

arr=one
arr={${arr[@]},two}
arr={${arr[@]},three}

for i in ${arr[@]}; do
	echo $i

done

arr={${arr[@]},four}
arr={${arr[@]},five}

for i in ${arr[@]}; do
	echo $i

done
