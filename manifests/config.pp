#
# == Definition: postfix::config
#
# Uses Augeas to add/alter/remove options in postfix main
# configuation file (/etc/postfix/main.cf).
#
# TODO: make this a type with an Augeas and a postconf providers.
#
# === Parameters
#
# [*name*]   - name of the parameter.
# [*ensure*] - present/absent/blank. defaults to present.
# [*value*]  - value of the parameter.
#
# === Requires
#
# - Class["postfix"]
#
# === Examples
#
#   postfix::config { 'smtp_use_tls':
#     ensure => 'present',
#     value  => 'yes',
#   }
#
#   postfix::config { 'relayhost':
#     ensure => 'blank',
#   }
#
define postfix::config (
  Optional[String]                   $value  = undef,
  Enum['present', 'absent', 'blank'] $ensure = 'present',
  Boolean                            $force  = false,
) {
  include postfix

  if ($ensure == 'present') {
    assert_type(Pattern[/^.+$/], $value) |$e, $a| {
      fail "value for parameter: ${title} can not be empty if ensure = present"
    }
  }

  if (!defined(Class['postfix'])) {
    fail 'You must define class postfix before using postfix::config!'
  }

  $postconf_cmd = '/usr/sbin/postconf'

  case $ensure {
    'present': {
      $cmd = "-e '${name}=${value}'"
      $test_value = "'${value}'"
    }
    'absent': {
      $cmd = "-# '${name}'"
      $test_value = "\"$(${postconf_cmd} -dh '${name}')\""
    }
    'blank': {
      $cmd = "-e ${name}=''"
      $test_value = "''"
    }
    default: {
      fail "Unknown value for ensure '${ensure}'"
    }
  }
  
  if $force {
    $extra_test = "-z \"$(${postconf_cmd} -nH 2>/dev/null | grep ${name})\" -o "
  } else {
    $extra_test = ''
  }

  exec { "manage postfix '${title}'":
    notify  => Service['postfix'],
    command => "${postconf_cmd} ${cmd}",
    onlyif  => "/usr/bin/test ${extra_test} \"$(${postconf_cmd} -h ${name} 2>/dev/null)\" != ${test_value}",
    cwd     => '/',
    timeout => 30,
  }

  Postfix::Config[$title] ~> Class['postfix::service']
}
