class apache {
    package { [ "httpd", "httpd-devel", "mod_ssl" ]: 
        ensure => present;
    }

    service { "httpd":
        ensure    => running,
        enable    => true,
        hasstatus => true,
        require   => [ Package["httpd"], Package["mod_ssl"] ],
        subscribe => [ File["/etc/httpd/conf/httpd.conf"], File["/etc/httpd/conf.d"] ];
    }

    file {
        "/etc/httpd/conf/httpd.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/apache/httpd.conf";
       
        "/etc/httpd/conf.d":
            ensure  => directory,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            recurse => true;

        "/etc/httpd/conf.d/ssl.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            content => template("apache/ssl.conf.erb"),
            notify  => Service["httpd"];
    }
}

class apache::passenger inherits apache {
    package { [ "rubygem-passenger", "ruby-mysql", "rubygem-activerecord", "rubygem-rake" ]:
        ensure  => present,
        require => Package["httpd"];
    }
    
    file {
        "/etc/httpd/conf.d/passenger.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/apache/passenger.conf",
            require => [ Package["rubygem-passenger"], Package["httpd"] ],
            notify  => Service["httpd"];
    }
}
