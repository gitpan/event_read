#    Monitor NT Event Logs
#	Rich Bowen	
#	rbowen@databeam.com
#	rbowen@rcbowen.com
#	10/3/1997
######
$inifile= "c:/perl/scripts/eventlog.ini";
use Win32::EventLog;
my $EventLog;

#  Read in the ini file
open (INI, "$inifile");
for (<INI>)	{
	chomp;
	if (m/^PAUSE: /) {s/^PAUSE: //; $pause=$_};
	if (m/^NOTIFY: /) {s/^NOTIFY: //; push @notify, $_};
	if (m/^SERVER: /) {s/^SERVER: //; push @servers, $_};
	if (m/^LASTRUN: /) {s/^LASTRUN: //; $lastrun=$_}
	if (m/^SEARCH: /) {
		s/^SEARCH: //;
		($key, $value) = split (/==/, $_);
		$value =~ s/^\/|\/$//g;
		$Search{$key} = $value;
		# print "$key = $value\n";
	 	}
	}
close INI;
chomp(@notify);

my %event=( 
                'Length',NULL, 
                'RecordNumber',NULL, 
                'TimeGenerated',NULL, 
                'TimeWritten',NULL, 
                'EventID',NULL,
                'EventType',NULL,  
                'Category',NULL, 
                'ClosingRecordNumber',NULL, 
                'Source',NULL, 
                'Computer',NULL, 
                'Strings',NULL,
                'Data',NULL, 
);
@etype_text = ("None", "Error", "Warning", 
		"N/A", "Information",  "N/A",
		"N/A",  "N/A", "Sucess Audit", 
		"N/A", "N/A", "N/A", "N/A", "N/A", 
		"N/A", "N/A", "Failure Audit" );
 

# Figure out what computers we need to look at
chomp(@servers);

#  loop forever
while (1)	{
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
print "\n__ $hour:$min:$sec - $mon/$mday/$year ___\n";


for $server (@servers)	{
	($servername, $event_log) = split (/~/,$server);
	print "Checking $servername $event_log Log\n";

#Opening the log file on my computer, looking for system's events       
Open Win32::EventLog($EventLog,$event_log,$servername) || die $!;

#  Get the events

#  What is the last entry in the log?
$EventLog->GetNumber($lastnum);
$EventLog->Read((EVENTLOG_SEEK_READ | EVENTLOG_FORWARDS_READ),$lastnum,$event);
$event_time = $event->{'TimeGenerated'};
if ($event_time > $lastevent_time) {$lastevent_time = $event_time};
$lastevent_time++;

while ($event_time > $lastrun) {

	$EventLog->Read((EVENTLOG_SEEK_READ | EVENTLOG_FORWARDS_READ),$lastnum,$event);
	$lastnum--;

	#Conversion of the date
	$event_time = $event->{'TimeGenerated'};
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($event_time);
	
	#printing the event
	$mon++;
	print "date : $mon/$mday/$year, $hour:$min:$sec\n";

	#to get a readable EventId
	$event->{'EventID'} = $event->{'EventID'} & 0xffff;

	#  "Strings" is null (\000) terminated
	$event->{'Strings'} =~ s/\000/\n\t/g;
	$event->{'Strings'} =~ s/\n\t$//;

	#  What was the event type?
	$event->{'EventType'} = $etype_text[$event->{'EventType'}];

	foreach $i (keys %event) {
        	print "$i : $event->{$i} \n";
		}

	print "\n\n";

	#  Was this a message that we want to inform people about?
	$inform=0;
	for (keys %Search)	{
		if ($event->{$_} =~ /$Search{$_}/i)	{
			$inform=1;
			} #  End if
		}  #  End for
	if ($inform)	{
	    for $machine (@notify)	{
		$event->{'Strings'} =~ s#/#\\#g;
		`net send $machine Error message from $servername: $event->{'EventType'} ($mon/$mday/$year at $hour:$min:$sec) Source: $event->{'Source'} Message: $event->{'Strings'}`;
		}  #  End for
	    }  #  End if not
		
	}  #  Wend
	
}  #  End for servers

#  Restore the ini file
open (INI, ">$inifile");
print INI "Settings for event_read Event Log monitor\n";
print INI "\nTime between checks, in seconds\nPAUSE: $pause\n";
print INI "\nList of machines to notify of errors\n";
for (@notify) { print INI "NOTIFY: $_\n" };
print INI "\n";
print INI "List of servers to check:  Servername~Log to check\n";
for (@servers) {print  INI "SERVER: $_\n" };
print INI "\n";
print INI "Things to search for.  This is done with regexes so be careful ...\n";
print INI "Your choice of fields is:\n\tSource\n\tEventType\n\tStrings\n\tData\n";
for (keys %Search)	{
	print INI "SEARCH: $_==/$Search{$_}/\n"
	}
print INI "\nDon't edit this line - this indicates when we last checked the logs\n";
print INI "LASTRUN: $lastevent_time\n";
close INI;

#  End loop
print "__ Done checking __\n";
sleep($pause);
}
