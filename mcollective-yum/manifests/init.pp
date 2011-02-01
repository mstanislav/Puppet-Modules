define mcollective::script {
    file { "/usr/sbin/$title":
        ensure  => present,
        owner   => "root",
        group   => "root",
        mode    => "0755",
        source  => "puppet:///modules/mcollective/sbin/$title",
        require => Package["mcollective"],
        notify  => Service["mcollective"];
    }
}

class mcollective {
    mcollective::script { "mc-filemgr": }
    mcollective::script { "mc-iptables": }
    mcollective::script { "mc-package": }
    mcollective::script { "mc-peermap": }
    mcollective::script { "mc-pgrep": }
    mcollective::script { "mc-puppetd": }
    mcollective::script { "mc-service": }
    mcollective::script { "mc-spamassassin": }
    mcollective::script { "mc-urltest": }

    package { [ "rubygems", "rubygem-stomp", "mcollective-common", "mcollective-client", "mcollective" ]:
        ensure => present,
        require => [ Yumrepo["mnxsolutions"], Yumrepo["epel"] ];
    }

    service { "mcollective":
        ensure  => running,
        enable  => true,
        require => Package["mcollective"];
    }

    exec { "gem install net-ping":
        unless => "test -f /usr/lib/ruby/gems/1.8/gems/net-ping-1.3.7/lib/net/ping.rb",
        require => Package["rubygems"];
    }

    file {
        "/etc/mcollective/server.cfg":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            content => template("mcollective/server.erb"),
            require => Package["mcollective"],
            notify  => Service["mcollective"];

        "/etc/mcollective/client.cfg":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/client.cfg",
            require => Package["mcollective"],
            notify  => Service["mcollective"];

        "/usr/lib/ruby/site_ruby/1.8/proctable.rb":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            source  => "puppet:///modules/mcollective/proctable.rb",
            require => Package["mcollective"];

        "/usr/libexec/mcollective/mcollective/agent":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            source  => "puppet:///modules/mcollective/agent",
            recurse => true,
            require => Package["mcollective"],
            notify  => Service["mcollective"];

        "/usr/libexec/mcollective/mcollective/facts":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            source  => "puppet:///modules/mcollective/facts",
            recurse => true,
            require => Package["mcollective"],
            notify  => Service["mcollective"];

        "/usr/libexec/mcollective/mcollective/registration":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0755",
            source  => "puppet:///modules/mcollective/registration",
            recurse => true,
            require => Package["mcollective"],
            notify  => Service["mcollective"];
    }
}

class mcollective::parent {
    package { [ "activemq", "activemq-info-provider", "tanukiwrapper.$architecture", "java-1.6.0-openjdk" ]:
        ensure  => latest,
        require => Yumrepo["mnxsolutions"];
    }

    service { "activemq":
        ensure    => running,
        enable    => true,
        hasstatus => true,
        require   => [ Package["activemq"], Package["activemq-info-provider"], Package["tanukiwrapper.$architecture"] ];
    }

    file {
        "/etc/activemq/activemq.xml":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/activemq.xml",
            require => [ Package["activemq"], Package["activemq-info-provider"] ],
            notify  => Service["activemq"];

        "/etc/activemq/wrapper.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/mcollective/activemq-wrapper.conf",
            require => [ Package["activemq"], Package["activemq-info-provider"] ],
            notify  => Service["activemq"];
    }
}
