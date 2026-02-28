module Admin
  class SalesController < Admin::ApplicationController
    before_action :require_admin
    before_action :set_sale, only: %i[show edit update destroy]

    def index
      @sales = Sale.order(:starts_at)
    end

    def show
    end

    def new
      @sale = Sale.new
    end

    def create
      @sale = Sale.new(sale_params)
      if @sale.save
        redirect_to admin_sales_path, notice: "Sale created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @sale.update(sale_params)
        redirect_to admin_sales_path, notice: "Sale updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sale.destroy
      redirect_to admin_sales_path, notice: "Sale deleted."
    end

    private

    def set_sale
      @sale = Sale.find(params[:id])
    end

    def sale_params
      params.require(:sale).permit(:name, :description, :starts_at, :ends_at, :discount_notches, :product_id, :quantity)
    end
  end
end
