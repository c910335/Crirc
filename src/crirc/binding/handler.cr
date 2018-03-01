require "./trigger"

# Register hooks to handle the behavior of a system based on a message.
module Crirc::Binding::Handler
  alias HookRule = String | Regex | Nil
  alias Hook = (Crirc::Protocol::Message, Regex::MatchData?) ->

  # Hooks associated with `Trigger`
  getter hooks : Hash(Trigger, Array(Hook))

  # Documentation lines for each hook
  getter docs : Hash(String, String)

  def initialize(**opts)
    super(**opts)
    @hooks = Hash(Trigger, Array(Hook)).new
    @docs = Hash(String, String).new
  end

  # Register a hook on a command name (JOIN, PRIVMSG, ...) and other rules
  def on(command : String = "PRIVMSG", source : HookRule = nil, arguments : HookRule = nil, message : HookRule = nil,
         doc : {String, String}? = nil, &hook : Hook)
    rule = Trigger.new(command, source, arguments, message)
    self.hooks.fetch(rule) { self.hooks[rule] = Array(Hook).new }
    self.hooks[rule] << hook
    @docs[doc[0]] = doc[1] unless doc.nil?
    self
  end

  # Handle one `Message`
  # It goes through the registred hooks, select the one to trigger.
  # Then, it execute every hooks associated, and send as parameters the current message and the regex match if possible
  # TODO: msg should NEVER be modified in the hook. (copy ? readonly ? struct ?)
  def handle(msg : Crirc::Protocol::Message)
    selected_hooks = self.hooks.select { |rule, hooks| rule.test(msg) }
    selected_hooks.each do |rule, hooks|
      hooks.each do |hook|
        message_to_handle = msg.message
        rule_message = rule.message
        match = if message_to_handle && rule_message.is_a?(Regex)
                  rule_message.match message_to_handle
                end
        hook.call msg, match
      end
    end
    self.hooks.fetch(msg.command) { Array(Hook).new }
    self
  end

  # Sugar for `handle` that parse the string as a `Crirc::Protocol::Message`
  def handle(msg : String)
    handle Crirc::Protocol::Message.new(msg)
  end
end
