$0 = "master"
ARGV << "--rack"
require 'puppet/application/master'
run Puppet::Application[:master].run
