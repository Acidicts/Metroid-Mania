module ShipRequestsHelper
  # Render a status badge for a ShipRequest (keeps styling consistent with admin UI)
  # Examples:
  #   ship_request_status_badge(request)
  #   => <span class="status-badge status-pending">Pending</span>
  def ship_request_status_badge(ship_request)
    return "" unless ship_request

    klass = if ship_request.pending?
      "status-pending"
    elsif ship_request.status.to_s == "rejected"
      "status-denied"
    else
      "status-fulfilled"
    end

    content_tag(:span, ship_request.status.to_s.humanize, class: "status-badge #{klass}")
  end

  def project_eligible(project)
    return false unless project
    return false unless project.eligible_for_ship_request?
    return false if project.ship_requests.where(status: "pending").exists?
    true
  end

  def ship_checklist(project)
    return "" if project.nil?

    <<~MD
      - [#{project.devlogged_minutes_since_baseline >= 15 ? "x" : " "}] At least 15 minutes of devlogs since last ship or project creation
      - [#{project.ship_requests.where(status: 'pending').exists? ? " " : "x"}] No existing pending ship request
      - [#{project.github_repo_public? ? "x" : " "}] Github Repo is Public
      - [#{project.github_readme_present? ? "x" : " "}] Project has a README
      - [#{project.clonable? ? "x" : " "}] Project is clonable
      - [#{(project.respond_to?(:image) && project.image.attached?) ? "x" : " "}] Project has a banner image
    MD
  end

  # Render the action controls for ship-requests on a project show card.
  # Mirrors the existing conditional logic previously present in
  # `projects/show.html.erb` so views can call a single helper instead of
  # duplicating the logic.
  def ship_request_action_buttons(project)
    return "".html_safe unless project

    parts = []

    if project.user == current_user
      if project.computed_shipped?
        minutes_since = (project.devlogs.where("created_at >= ?", project.computed_shipped_at || project.approved_at || project.created_at).sum(:duration_seconds).to_i / 60)
        if minutes_since >= 15
          parts << button_to("Request another ship", project_ship_requests_path(project), method: :post, data: { confirm: "Request a new ship?" }, class: "btn-retro")
        else
          parts << content_tag(:span, "Add a devlog to request another ship.", style: "color:var(--main-700);")
        end

      elsif project.computed_status == "pending"
        if project.ship_requests.where(status: "pending").exists?
          req = project.ship_requests.where(status: "pending").first
          parts << link_to("View request", project_ship_request_path(project, req), class: "btn-retro btn-retro--outline")
        end

      elsif !project.eligible_for_ship_request?
        remaining = [15 - project.devlogged_minutes_since_baseline.to_i, 0].max # rubocop:disable Layout/SpaceInsideArrayLiteralBrackets
        parts << content_tag(:span, "You need <strong style=\"font-family:monospace;\">#{remaining}</strong> more minutes of devlogs".html_safe, style: "font-size:1.2rem;")

      elsif project.eligible_for_ship_request?
        if project.ships.exists?
          parts << link_to("Ship Again", new_project_ship_request_path(project), class: "btn-retro")
        elsif project.ship_requests.where(status: "pending").exists?
          parts << link_to("View pending request", project_ship_request_path(project, project.ship_requests.where(status: "pending").first), class: "btn-retro btn-retro--outline")
        else
          parts << link_to("Ship", new_project_ship_request_path(project), class: "btn-retro")
        end
      end
    else
      parts << link_to("Back to projects", projects_path, class: "btn-retro btn-retro--outline")
    end

    safe_join(parts, " ")
  end

  # Nicely format the devlogged seconds stored on a ShipRequest
  def ship_request_devlogged_formatted(ship_request)
    format_duration(ship_request.devlogged_seconds.to_i)
  end
end
