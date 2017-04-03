use strict;
use warnings;

use Text::CSV_PP;
use LWP::Simple;
use JSON;
use DateTime;

my $getListOfTickers = get("http://www.nasdaq.com/screening/companies-by-name.aspx?letter=0&exchange=nasdaq&render=download")
  or die "are you connected to net??";

# Symbol Name LastSale MarketCap IPOyear Sector industry Summary Quote

my @listIncrease;
my %increaseTickers;
my @listDecrease;
my %decreaseTickers;
my @tickerList = split(/[\r\n]+/, $getListOfTickers);

my $parser = Text::CSV_PP->new();
my %tickers;
my $first = 1;

foreach my $tickerInfo (@tickerList) {
  if ($first) {
    $first = 0;
    next;
  }

  chomp $tickerInfo;
  $parser->parse($tickerInfo);
  my @listOfTickerInfo = $parser->fields();
  $tickers{$listOfTickerInfo[0]}{"Name"} = $listOfTickerInfo[1];
  $tickers{$listOfTickerInfo[0]}{"IPOyear"} = $listOfTickerInfo[4];
  $tickers{$listOfTickerInfo[0]}{"Sector"} = $listOfTickerInfo[5];
  $tickers{$listOfTickerInfo[0]}{"Industry"} = $listOfTickerInfo[6];
}

my @dates;

for (my $i = 0; $i < 10; $i++) {
  my $dt = DateTime->now->subtract(days => $i);
  my $yearNow = $dt->year();
  my $monthNow = $dt->month();
  my $dayNow = $dt->day();

  my $dateNow = $yearNow . "-";
  if ($monthNow < 10) {
    $dateNow = $dateNow . "0";
  }
  $dateNow = $dateNow . $monthNow . "-";
  if ($dayNow < 10) {
    $dateNow = $dateNow . "0";
  }
  $dateNow = $dateNow . $dayNow;

  push @dates, $dateNow;
}

my $timeSeriesCall = "http://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=";
# Change the apikey here
my $apiKey = "&apikey=xxxx";
my $tickerCount = 0;
for my $ticker (keys %tickers) {
  my $numberOfAttempts = 0;
  my $call = $timeSeriesCall . $ticker . $apiKey;
  my $timeSeriesInJson = get($call)
    or die "are you connected to net??";
  while (($timeSeriesInJson =~ /Error Message/) && $numberOfAttempts <= 2) {
    $numberOfAttempts++;
    my $timeSeriesInJson = get($call)
      or die "are you connected to net??";
  }
  if ($timeSeriesInJson =~ /Error Message/) {
    print "Call failed for ticker $ticker\n";
    next;
  }
  my $timeSeries = decode_json($timeSeriesInJson);
  my $timeSeriesOnly = $timeSeries->{"Time Series (Daily)"};

  my $count = 0;
  my @closePrices;
  for my $date (@dates) {
    if (exists $timeSeriesOnly->{$date}) {
      my $closePrice = $timeSeriesOnly->{$date}->{"4. close"} + 0;
      push @closePrices, $closePrice;
      $count++;
      if ($count >=4 ) {
        last;
      }
    }
  }
#  print "Closing prices for $ticker are $closePrices[0], $closePrices[1], $closePrices[2], $closePrices[3]\n";

  if (!(exists $closePrices[0] && exists $closePrices[1] &&
  exists $closePrices[2] && exists $closePrices[3])) {
    print "Could not get price for $ticker\n";
    next;
  }

  if (($closePrices[0]-$closePrices[1] > 0) &&
  ($closePrices[1]-$closePrices[2] > 0) &&
  ($closePrices[2]-$closePrices[3] > 0)  ) {
    my $increase = $closePrices[0] - $closePrices[3];
    my $percentIncrease = ($increase*100)/$closePrices[3];
    my $size = @listIncrease;
    #print "Increase in $ticker of $increase\n";
    push @listIncrease, $percentIncrease;
    $increaseTickers{$percentIncrease} = $ticker;
    #@listIncrease = sort { $a <=> $b} @listIncrease;
  }
  if (($closePrices[0]-$closePrices[1] < 0) &&
  ($closePrices[1]-$closePrices[2] < 0) &&
  ($closePrices[2]-$closePrices[3] < 0)  ) {
    my $decrease = $closePrices[3] - $closePrices[0];
    my $percentDecrease = ($decrease*100)/$closePrices[3];
    my $size = @listDecrease;
    #print "Decrease in $ticker of $decrease\n";
    push @listDecrease, $percentDecrease;
    $decreaseTickers{$percentDecrease} = $ticker;
    #@listDecrease = sort { $a <=> $b} @listDecrease;
  }
  $tickerCount++;
  if ($tickerCount%50 == 0) {
    print "$tickerCount Tickers Processed\n";
  }
}

print "Printing the increasing ones\n";
@listDecrease = sort { $b <=> $a} @listDecrease;
@listIncrease = sort { $b <=> $a} @listIncrease;
for (my $i = 0; $i < 30; $i++) {
  print "$increaseTickers{$listIncrease[$i]} - $listIncrease[$i]\n";
}

print "Printing the decreasing ones\n";

for (my $i = 0; $i < 30; $i++) {
  print "$decreaseTickers{$listDecrease[$i]} - $listDecrease[$i]\n";
}
