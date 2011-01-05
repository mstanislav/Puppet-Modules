class nrpe {
    package { [ "nagios-nrpe-server", "nagios-plugins", "libnagios-plugin-perl", "libcache-cache-perl" ]: ensure => present }

    service { "nagios-nrpe-server":
        ensure  => running,
        enable  => true,
        pattern => "nrpe",
        require => Package["nagios-nrpe-server"],
    }

    file {
        "/usr/lib/nagios/plugins/contrib":
            ensure  => directory,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            recurse => true,
            purge   => true,
            source  => "puppet:///modules/nrpe/contrib",
            require => Package["nagios-nrpe-server"],
            notify  => Service["nagios-nrpe-server"];

        "/etc/nagios/nrpe.cfg":
            ensure  => present,
            owner   => "nagios",
            group   => "nagios",
            mode    => "0664",
            source  => "puppet:///modules/nrpe/nrpe.cfg",
            require => Package["nagios-nrpe-server"],
            notify  => Service["nagios-nrpe-server"];
    }

    tidy { "/etc/default":
        recurse => true,
        matches => "nagios-nrpe-server",
    }
}
