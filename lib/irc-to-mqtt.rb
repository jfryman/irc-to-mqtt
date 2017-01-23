#!/usr/bin/env ruby

require 'rubygems'
require 'cinch'
require 'json'
require 'mqtt'
require 'raven'
require 'scrolls'


MQTT_URI = ENV['MQTT_URI']
IRC_SERVER = ENV['IRC_SERVER']
IRC_USERNAME = ENV['IRC_USERNAME']
IRC_PASSWORD = ENV['IRC_PASSWORD']
IRC_PORT = ENV['IRC_PORT']
IRC_NICK = ENV['IRC_NICK']
IRC_NETWORK = ENV['IRC_NETWORK']
MQTT_TOPIC_BASE = [
  "irc",
  IRC_NETWORK,
  IRC_NICK
].join('/')

class MqttWorker
  def initialize(bot)
    @bot = bot
    @queue = MQTT::Client.connect MQTT_URI

    @queue.subscribe([MQTT_TOPIC_BASE, '#'].join('/'))
  end

  def start
    @queue.get do |topic, message|
      @bot.handlers.dispatch(:mqtt_message, nil, topic, message.chomp) if topic.match '/in$'
    end
  end
end

class MqttBridge
  include Cinch::Plugin

  def initialize(*args)
    super

    @queue = MQTT::Client.connect MQTT_URI
  end

  def room_to_topic(room)
    [
      "irc",
      IRC_NETWORK,
      IRC_NICK,
      room.gsub(/^#/, ''),
      'out'
    ].join('/')
  end

  def network_from_topic(topic)
    topic_extract(topic, 1)
  end

  def nick_from_topic(topic)
    topic_extract(topic, 2)
  end

  def room_from_topic(topic)
    "##{topic_extract(topic, 3)}"
  end

  def topic_extract(topic, index)
    topic.split('/')[index]
  end

  set :prefix, //
  match /(.*)/
  def execute(m)
    topic = room_to_topic m.channel.name
    message = m.message

    @queue.publish(topic, message)
  end

  listen_to :mqtt_message
  def listen(m, topic, message)
    room = room_from_topic topic

    Channel(room).send message
  end
end

### Main Application
bot = Cinch::Bot.new do
  configure do |c|
    c.server = IRC_SERVER
    c.user = IRC_USERNAME
    c.password = IRC_PASSWORD
    c.port = IRC_PORT
    c.plugins.plugins = [MqttBridge]
  end
end

Thread.new do
  MqttWorker.new(bot).start
end

bot.start
