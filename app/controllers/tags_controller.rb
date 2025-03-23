require "ostruct"

class TagsController < ApplicationController
  before_action :find_tag
  before_action :find_repository, only: [:bulk_destroy]

  def show
  end

  def destroy
    reject_destroy unless Rails.configuration.x.delete_enabled

    if @tag.delete
      redirect_with_flash :notice, "The tag #{@tag.name} has been deleted."
    else
      redirect_with_flash :error, "The tag #{@tag.name} could not be deleted."
    end
  rescue Faraday::ClientError => e
    case e.response[:status]
    when 401
      client_error(e)
      retry
    when 405
      render :destroy_blocked
    else
      raise
    end
  end

  def bulk_destroy
    reject_destroy unless Rails.configuration.x.delete_enabled

    tag_names = params[:tag_names] || []
    success_count = 0
    failed_tags = []
    not_found_tags = []

    tag_names.each do |tag_name|
      begin
        tag = Tag.find(repository: @repository, name: tag_name)
        if tag.content_digest.nil?
          not_found_tags << tag_name
        elsif tag.delete
          success_count += 1
        else
          failed_tags << tag_name
        end
      rescue Faraday::ClientError => e
        case e.response[:status]
        when 401
          client_error(e)
          retry
        when 405
          failed_tags << tag_name
        else
          raise
        end
      end
    end

    messages = []
    messages << "Successfully deleted #{success_count} tag(s)." if success_count > 0
    messages << "Failed to delete #{failed_tags.size} tag(s): #{failed_tags.join(', ')}" if failed_tags.any?
    messages << "#{not_found_tags.size} tag(s) not found: #{not_found_tags.join(', ')}" if not_found_tags.any?

    if messages.empty?
      redirect_with_flash :error, "No tags were deleted."
    else
      redirect_with_flash :notice, messages.join(" ")
    end
  end

  private

  def find_tag
    @repository = Repository.find params[:repo]
    @tag        = Tag.find(repository: @repository, name: params[:tag])
  end

  def find_repository
    @repository = Repository.find params[:repo]
  end

  def redirect_with_flash(type, message)
    redirect_to repository_path(@repository.name), flash: { type => message }
  end

  def reject_destroy
    raise "Tag deletion feature is not enabled.\nPlease set `ENABLE_DELETE_IMAGES=true` to enable it."
  end
end
