# frozen_string_literal: true

module HasHintedAssociations
  extend ActiveSupport::Concern

  class HintedAssociation < ActiveRecord::Associations::HasManyAssociation
    def loaded?
      !has_hinted_association? || super
    end

    def has_hinted_association?
      owner._hinted_associations.include?(reflection.name.to_s)
    end
  end

  module HintedReflectionExtension
    def association_class
      HintedAssociation
    end
  end

  included do
    def self.has_many_hinted(name, *args)
      has_many name, *args,
        after_add: Proc.new { |owner, _associatied| owner.update_hints(name) },
        after_remove: Proc.new { |owner, _associatied| owner.update_hints(name) }

      class << reflect_on_association(name)
        prepend HintedReflectionExtension
      end
    end

    def update_hints(name)
      if send(name).size.zero?
        _hinted_associations.delete(name.to_s)
      else
        _hinted_associations << name.to_s if !_hinted_associations.include?(name.to_s)
      end
    end
  end
end

# Should probably be a Railtie, or freedom patch. Putting here for now
# This ensures the `where` clause for preloading only includes IDs that have a hint
module HintedPreloaderExtension
  def grouped_records(_association, _records, _polymorphic_parent)
    super.each do |reflection, records|
      next if reflection.association_class != HasHintedAssociations::HintedAssociation
      records.delete_if { |r| !r.association(reflection.name).has_hinted_association? }
    end
  end
end
ActiveRecord::Associations::Preloader.prepend HintedPreloaderExtension
