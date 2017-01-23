#!/usr/bin/env ruby

require 'rubygems'
require 'cinch'
require 'json'
require 'mqtt'
require 'raven'
require 'scrolls'
require 'pry'


MQTT_URI = ENV['MQTT_URI']
MQTT_TOPIC_BASE = ENV['MQTT_TOPIC_BASE']
IRC_SERVER = ENV['IRC_SERVER']
IRC_USERNAME = ENV['IRC_USERNAME']
IRC_PASSWORD = ENV['IRC_PASSWORD']
IRC_PORT = ENV['IRC_PORT']

class MqttWorker
  def initialize(bot)
    @bot = bot
    @queue = MQTT::Client.connect MQTT_URI

    @queue.subscribe([MQTT_TOPIC_BASE, '#'].join('/'))
  end

  def start
    @queue.get do |topic, message|
      @bot.handlers.dispatch(:mqtt_message, nil, topic, message)
    end
  end
end

class MqttBridge
  include Cinch::Plugin

  def initialize
    @queue = MQTT::Client.connect MQTT_URI
  end

  def room_to_topic(room)
    room
  end

  def room_from_topic(topic)
    topic[/room\/(\w+)\//,1]
  end

  match /^$/
  def execute(m)
    topic = room_to_topic m.room
    message = m.message

    @queue.publish(topic, message)
  end

  listen_to :mqtt_message
  def send(m, topic, message)
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
