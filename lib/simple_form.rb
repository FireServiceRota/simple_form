# frozen_string_literal: true
require 'action_view'
require 'action_pack'
require 'simple_form/action_view_extensions/form_helper'
require 'simple_form/action_view_extensions/builder'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/reverse_merge'

module SimpleForm
  extend ActiveSupport::Autoload

  autoload :Helpers
  autoload :Wrappers

  eager_autoload do
    autoload :Components
    autoload :ErrorNotification
    autoload :FormBuilder
    autoload :Inputs
  end

  def self.eager_load!
    super
    SimpleForm::Inputs.eager_load!
    SimpleForm::Components.eager_load!
  end

  CUSTOM_INPUT_DEPRECATION_WARN = <<-WARN
  WARN

  FILE_METHODS_DEPRECATION_WARN = <<-WARN
  WARN

  @@configured = false

  def self.configured? #:nodoc:
    @@configured
  end

  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new("5.3", "SimpleForm")
  end

  ## CONFIGURATION OPTIONS

  def self.current
    RequestStore[:simple_form]
  end

  class << self
    delegate :error_method,
    :error_notification_tag,
    :error_notification_class,
    :collection_label_methods,
    :collection_value_methods,
    :collection_wrapper_tag,
    :collection_wrapper_class,
    :item_wrapper_tag,
    :item_wrapper_class,
    :label_text,
    :label_class,
    :boolean_style,
    :form_class,
    :default_form_class,
    :generate_additional_classes_for,
    :required_by_default,
    :browser_validations,
    :input_mappings,
    :wrapper_mappings,
    :custom_inputs_namespaces,
    :time_zone_priority,
    :country_priority,
    :translate_labels,
    :inputs_discovery,
    :cache_discovery,
    :button_class,
    :field_error_proc,
    :input_class,
    :include_default_input_wrapper_class,
    :boolean_label_class,
    :default_wrapper,
    :i18n_scope,
    :input_field_error_class,
    :input_field_valid_class,
    :wrappers,
    :wrapper,
    to: :current
  end


  class Config
    attr_accessor :error_method,
      :error_notification_tag,
      :error_notification_class,
      :collection_label_methods,
      :collection_value_methods,
      :collection_wrapper_tag,
      :collection_wrapper_class,
      :item_wrapper_tag,
      :item_wrapper_class,
      :label_text,
      :label_class,
      :boolean_style,
      :form_class,
      :default_form_class,
      :generate_additional_classes_for,
      :required_by_default,
      :browser_validations,
      :input_mappings,
      :wrapper_mappings,
      :custom_inputs_namespaces,
      :time_zone_priority,
      :country_priority,
      :translate_labels,
      :inputs_discovery,
      :cache_discovery,
      :button_class,
      :field_error_proc,
      :input_class,
      :include_default_input_wrapper_class,
      :boolean_label_class,
      :default_wrapper,
      :i18n_scope,
      :input_field_error_class,
      :input_field_valid_class,
      :wrappers
    def initialize
      @error_method = :first
      @error_notification_tag = :p
      @error_notification_class = :error_notification
      @collection_label_methods = %i[to_label name title to_s]
      @collection_value_methods = %i[id to_s]
      @collection_wrapper_tag = nil
      @collection_wrapper_class = nil
      @item_wrapper_tag = :span
      @item_wrapper_class = nil
      @label_text = ->(label, required, explicit_label) { "#{required} #{label}" }
      @label_class = nil
      @boolean_style = :inline
      @form_class = :simple_form
      @default_form_class = nil
      @generate_additional_classes_for = %i[wrapper label input]
      @required_by_default = true
      @browser_validations = true
      @input_mappings = nil
      @wrapper_mappings = nil
      @custom_inputs_namespaces = []
      @time_zone_priority = nil
      @country_priority = nil
      @translate_labels = true
      @inputs_discovery = true
      @cache_discovery = defined?(Rails.env) && !Rails.env.development?
      @button_class = 'button'
      @field_error_proc = proc do |html_tag, instance_tag|
        html_tag
      end
      @input_class = nil
      @include_default_input_wrapper_class = true
      @boolean_label_class = 'checkbox'
      @default_wrapper = :default
      @wrappers = {}
      @i18n_scope = 'simple_form'
      @input_field_error_class = nil
      @input_field_valid_class = nil

      wrappers class: :input, hint_class: :field_with_hint, error_class: :field_with_errors, valid_class: :field_without_errors do |b|
        b.use :html5

        b.use :min_max
        b.use :maxlength
        b.use :minlength
        b.use :placeholder
        b.optional :pattern
        b.optional :readonly

        b.use :label_input
        b.use :hint,  wrap_with: { tag: :span, class: :hint }
        b.use :error, wrap_with: { tag: :span, class: :error }
      end
    end

    # Retrieves a given wrapper
    def wrapper(name)
      @wrappers[name.to_s] or raise WrapperNotFound, "Couldn't find wrapper with name #{name}"
    end

    # Raised when fails to find a given wrapper name
    class WrapperNotFound < StandardError
    end

    # Define a new wrapper using SimpleForm::Wrappers::Builder
    # and store it in the given name.
    def wrappers(*args, &block)
      if block_given?
        options                 = args.extract_options!
        name                    = args.first || :default
        @wrappers[name.to_s]   = SimpleForm.build(options, &block)
      else
        @wrappers
      end
    end
  end

  # Builds a new wrapper using SimpleForm::Wrappers::Builder.
  def self.build(options = {})
    options[:tag] = :div if options[:tag].nil?
    builder = SimpleForm::Wrappers::Builder.new(options)
    yield builder
    SimpleForm::Wrappers::Root.new(builder.to_a, options)
  end

  def self.additional_classes_for(component)
    generate_additional_classes_for.include?(component) ? yield : []
  end

  ## SETUP

  def self.default_input_size=(*)
    SimpleForm.deprecator.warn "[SIMPLE_FORM] SimpleForm.default_input_size= is deprecated and has no effect", caller
  end

  # def self.form_class=(value)
  #   SimpleForm.deprecator.warn "[SIMPLE_FORM] SimpleForm.form_class= is deprecated and will be removed in 4.x. Use SimpleForm.default_form_class= instead", caller
  #
  #   @@form_class = value
  # end
  #
  # def self.file_methods=(file_methods)
  #   SimpleForm.deprecator.warn(FILE_METHODS_DEPRECATION_WARN, caller)
  #   @@file_methods = file_methods
  # end
  #
  # def self.file_methods
  #   SimpleForm.deprecator.warn(FILE_METHODS_DEPRECATION_WARN, caller)
  #   @@file_methods
  # end

  @@contexts = {}

  # Default way to setup Simple Form. Run rails generate simple_form:install
  # to create a fresh initializer with all configuration values.
  def self.setup(context: :default)
    config = context == :default ? Config.new : @@contexts[:default]&.dup
    config ||= Config.new
    @@contexts[context] = config
    @@configured = true
    yield config
  end

  def self.activate(context:)
    RequestStore[:simple_form] = @@contexts[context]
  end

  def self.include_component(component)
    if Module === component
      SimpleForm::Inputs::Base.include(component)
    else
      raise TypeError, "SimpleForm.include_component expects a module but got: #{component.class}"
    end
  end
end

require 'simple_form/railtie' if defined?(Rails)
