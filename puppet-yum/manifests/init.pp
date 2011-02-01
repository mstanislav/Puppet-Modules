class puppet {
    package { "puppet.noarch":
        ensure  => present,
        alias   => "puppet",
        require => Yumrepo["mnxsolutions"];
    }

    service { "puppet":
        ensure    => running,
        enable    => true,
        hasstatus => true,
        require   => Package["puppet"],
        subscribe => File["/etc/puppet/puppet.conf"];
    }

    file {
        "/etc/puppet/puppet.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => [ "puppet:///modules/puppet/puppet.conf-$hostname", 
                         "puppet:///modules/puppet/puppet.conf" ],
            require => Package["puppet"];
    }
}

class puppet::master inherits puppet {
    exec { "puppet cert":
        command     => "puppet cert --generate `hostname`",
        unless      => "test -f /var/lib/puppet/ssl/private_keys/`hostname`.pem",
        refreshonly => true,
        subscribe   => Package["puppet-server"];
    }

    package { "puppet-server.noarch":
        ensure  => present,
        alias   => "puppet-server",
        require => [ Yumrepo["mnxsolutions"], Package["httpd"], Package["rubygem-passenger"], Package["mysql-server"] ];
    }

    service { "puppetmaster":
        ensure  => stopped,
        enable  => false,
        require => Package["puppet-server"];
    }

    file {
        "/etc/httpd/conf.d/puppetmaster.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            content => template("puppet/puppetmaster-vhost.conf.erb"),
            require => Package["puppet-server"],
            notify  => Service["httpd"];
        
        "/etc/puppet/modules":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            require => Package["puppet-server"];
            
        "/usr/share/puppet/rack/puppetmasterd/public":
            ensure  => directory,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            require => Package["puppet-server"];

        "/usr/share/puppet/rack/puppetmasterd/tmp":
            ensure  => directory,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            require => Package["puppet-server"];
    
        "/usr/share/puppet/rack/puppetmasterd/config.ru":
            ensure  => present,
            owner   => "puppet",
            group   => "puppet",
            mode    => "0644",
            source  => "puppet:///modules/puppet/config.ru",
            require => Package["puppet-server"];
    }
}
