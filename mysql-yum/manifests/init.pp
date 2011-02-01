class mysql {
    package { [ "mysql-server", "mysql", "mysql-devel" ]: ensure => present; }
    
    service { "mysqld":
        ensure    => running,
        enable    => true,
        hasstatus => true,
        require   => Package["mysql-server"],
        subscribe => File["/etc/my.cnf"];
    }

    file {
        "/etc/my.cnf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mysql/my.cnf",
            require => Package["mysql-server"];
    }
}
