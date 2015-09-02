module Spree
  class AdyenRedirectController < StoreController
    before_filter :check_signature, :only => :confirm

    skip_before_filter :verify_authenticity_token

    def confirm

      order = current_order

      unless authorized?
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(order.state) and return
      end

      #manually set up the payment, constructed from adyen params & order details
      payment = order.payments.find_or_initialize_by(identifier: order.number)
      payment.amount=current_order.total
      payment.payment_method=payment_method
      payment.response_code=params[:pspReference]
      payment.save!

      #try to increment the order steps. Next step should take us to completion...
      order.next!

      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to order_path(order, :token => order.guest_token)
      else
        redirect_to checkout_state_path(order.state)
      end

    end


    def authorise3d

      if params[:MD].present? && params[:PaRes].present?
        md = params[:MD]
        pa_response = params[:PaRes]

        gateway_class = session[:adyen_gateway_name].constantize
        gateway = gateway_class.find(session[:adyen_gateway_id])

        response3d = gateway.authorise3d(md, pa_response, request.ip, request.headers.env)

        @payment = current_order.payments.find_by_identifier(session[:payment_identifier])
        @payment.response_code = response3d.psp_reference

        if response3d.success?
          @payment.pend
          @payment.save
          current_order.next
        else
          @payment.failure
          @payment.save
          flash.notice = Spree.t(:payment_processing_failed)
        end

      end

      # Update iframe and redirect parent to checkout state
      render partial: 'spree/shared/reload_parent', locals: {
        new_url: redirect_path
      }

    end

    private

      def pending?
        params[:authResult] == 'PENDING'
      end

      def extract_payment_identifier_from_merchant_reference(merchant_reference)
        merchant_reference.split('-').last
      end

      def authorized?
        params[:authResult] == "AUTHORISED"
      end

      def redirect_path
        if current_order.completed?
          cookies[:completed_order] = current_order.id
          @current_order = nil
          flash.notice = Spree.t(:order_processed_successfully)
          completion_route
        else
          checkout_state_path(current_order.state)
        end
      end

      def completion_route
        spree.checkout_complete_path
      end

      def check_signature
        unless ::Adyen::Form.redirect_signature_check(params, payment_method.shared_secret)
          raise "Payment Method not found."
        end
      end

      # TODO find a way to send the payment method id to Adyen servers and get
      # it back here to make sure we find the right payment method
      def payment_method
        @payment_method = current_order.available_payment_methods.find do |m|
                            m.is_a?(Spree::Gateway::AdyenHPP) && m.environment == Rails.env
                          end
      end

  end
end
