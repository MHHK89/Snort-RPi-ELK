#! /bin/bash
# Script to get CPU and Memory every next second on RPi
#It will also plot the results after provided time using Gnuplot
 

sudo rm status.dat

function mem_cpu() {

	end=$((SECONDS+605))

	echo "Printing memory and cpu consumption in status.dat file....... "
	while [ $SECONDS -lt $end ]; do
	
		MEMORY=$(free -m | awk 'NR==2{printf "%.2f\t\t", $3*100/$2 }')
		CPU=$(echo $[100-$(vmstat 1 2|tail -1|awk '{printf $15}')])

	echo -e  "$SECONDS\t\t$MEMORY$CPU" >>status.dat 
	sleep 1
	done
}

function gnu_plot() {
	sudo gnuplot -persist <<-EOFMarker
	set y2tics
# We don't want to see the left ticks on the right axis
	set ytics nomirror

# Set ranges so that the data points are not on the axis
	set xrange [0:620]   # "set autoscale x"  can also be used. It presents Time in Seconds 

	set yrange [0:110]   #Percentages
	set y2range[0:110]

# use first line of the file for labels
	set key autotitle columnhead
# display key in least busy area
	set key top right

# Title and axis labels
	set title "CPU and Memory Usage" # change title accordingly
	set xlabel "Time in Seconds"
	set ylabel "Memory%"
	set y2label "CPU%"

 
	plot "status.dat" using 1:2 axes x1y1 title 'Memory' with linespoints pointsize 0.5 pointtype 3,"" u 1:3 axes x1y2 title 'CPU' w linespoints ps 0.5 pointtype 7

EOFMarker

}

function main() {
	mem_cpu
	gnu_plot
}
main
