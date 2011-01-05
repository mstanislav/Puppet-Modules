class mcollective::apt {
    file {
        "/etc/apt/sources.list.d/puppetlabs.list":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/apt-puppetlabs",
            require => Exec["Puppet Labs APT GPG Key"],
            notify  => Exec["apt-get update"];

        "/etc/apt/sources.list.d/simplegeo.list":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/apt-simplegeo",
            require => Exec["SimpleGeo APT GPG Key"],
            notify  => Exec["apt-get update"];
    }

    exec {
        "gpg --keyserver pgpkeys.pca.dfn.de --recv-keys 1054B7A24BD6EC30 && gpg --export -a 1054B7A24BD6EC30 | apt-key add -":
            alias  => "Puppet Labs APT GPG Key",
            unless => "[ -n \"`apt-key list | grep Puppet`\" ]";

        "gpg --keyserver pgpkeys.pca.dfn.de --recv-keys 7D0EC843EB8C9BB1 && gpg --export -a 7D0EC843EB8C9BB1 | apt-key add -":
            alias  => "SimpleGeo APT GPG Key",
            unless => "[ -n \"`apt-key list | grep SimpleGeo`\" ]";

        "apt-get update":
            command     => "/usr/bin/apt-get update",
            logoutput   => false,
            refreshonly => true;
    }
}

class mcollective::parent {
    package { "activemq":
        ensure  => present,
        require => File["/etc/apt/sources.list.d/simplegeo.list"],
    }

    service { "activemq":
        ensure  => running,
        enable  => true,
        require => Package["activemq"],
    }

    file {
        "/etc/activemq/activemq.xml":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/activemq.xml",
            require => Package["activemq"],
            notify  => Service["activemq"];
    }
}

class mcollective::child {
    package { [ "mcollective-client", "mcollective-common", "mcollective", "mcollective-plugins" ]:
        ensure  => present,
        require => [ File["/etc/apt/sources.list.d/puppetlabs.list"], File["/etc/apt/sources.list.d/simplegeo.list"] ],
    }

    service { "mcollective":
        ensure  => running,
        enable  => true,
        require => Package["mcollective"],
    }

    file {
        "/etc/mcollective/server.cfg":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0440",
            content => template("mcollective/server.erb"),
            require => Package["mcollective"],
            notify  => Service["mcollective"];

        "/etc/mcollective/client.cfg":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0440",
            source  => "puppet:///modules/mcollective/client.cfg",
            require => Package["mcollective-client"],
            notify  => Service["mcollective"];
    }
}
