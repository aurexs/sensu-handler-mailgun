#!/usr/bin/env ruby
#
# Sensu Handler: mailgun
#
# This handler sends emails to a list of pre-defined recipients through the Mailgun API.
#
# Copyright 2014 Aurex <aurex@dizenia.me>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'rest-client'
require 'json'

class Mailgun < Sensu::Handler

  def short_name
      @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    api_key = settings['mailgun']['api_key']
    domain = settings['mailgun']['domain']
    sender_name = settings['mailgun']['sender_name']
    sender_email = settings['mailgun']['sender_email']
    candidates = settings['mailgun']['candidates']

    raise 'Por favor define claves validas de Mailgun para usar este handler' unless (api_key && domain && sender_email)
    raise 'Define los correos de envio (candidates) para usar este handler' if (candidates.nil? || candidates.empty?)

    recipients = []
    candidates.each do |email, candidate|
      if (((candidate['sensu_roles'].include?('all')) ||
          ((candidate['sensu_roles'] & @event['check']['subscribers']).size > 0) ||
          (candidate['sensu_checks'].include?(@event['check']['name']))) &&
          (candidate['sensu_level'] >= @event['check']['status']))
        recipients << email
      end
    end

    playbook = "Playbook:  #{@event['check']['playbook']}" if @event['check']['playbook']
    body = <<-BODY.gsub(/^\s+/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
            #{playbook}
          BODY
    subject = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    response = RestClient.post "https://api:#{api_key}"\
    "@api.mailgun.net/v2/#{domain}/messages",
    :from => "#{sender_name} <#{sender_email}>",
    :to => "#{recipients.join(', ')}",
    :subject => "#{subject}",
    :text => "#{body}"

    if response.code == 200
      puts "Notified #{recipients.join(', ')} for #{action_to_string}"
    else
      puts "Error al enviar correos: #{response.to_str}"
    end
  end
end
