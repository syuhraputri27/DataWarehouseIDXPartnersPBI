USE [DWH]
GO
/****** Object:  Table [dbo].[City]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[City](
	[CityID] [int] NOT NULL,
	[CityName] [varchar](50) NULL,
	[StateID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[CityID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimAccount]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimAccount](
	[AccountID] [int] NOT NULL,
	[CustomerID] [int] NOT NULL,
	[AccountType] [nvarchar](50) NOT NULL,
	[Balance] [int] NOT NULL,
	[DateOpened] [datetime] NOT NULL,
	[Status] [nvarchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[AccountID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimBranch]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimBranch](
	[BranchID] [int] NOT NULL,
	[BranchName] [nvarchar](100) NOT NULL,
	[BranchLocation] [nvarchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[BranchID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimCustomer]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimCustomer](
	[CustomerID] [int] NOT NULL,
	[CustomerName] [varchar](50) NULL,
	[Address] [varchar](max) NULL,
	[CityID] [int] NOT NULL,
	[Age] [int] NOT NULL,
	[Gender] [varchar](10) NULL,
	[Email] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[FactTransaction]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FactTransaction](
	[transaction_id] [int] NOT NULL,
	[account_id] [int] NULL,
	[transaction_date] [datetime] NULL,
	[amount] [int] NULL,
	[transaction_type] [varchar](10) NULL,
	[branch_id] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[transaction_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[State]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[State](
	[StateID] [int] NOT NULL,
	[StateName] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[StateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[City]  WITH CHECK ADD FOREIGN KEY([StateID])
REFERENCES [dbo].[State] ([StateID])
GO
ALTER TABLE [dbo].[DimAccount]  WITH CHECK ADD FOREIGN KEY([CustomerID])
REFERENCES [dbo].[DimCustomer] ([CustomerID])
GO
ALTER TABLE [dbo].[DimCustomer]  WITH CHECK ADD FOREIGN KEY([CityID])
REFERENCES [dbo].[City] ([CityID])
GO
/****** Object:  StoredProcedure [dbo].[BalancePerCustomer]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Balance Per Customer Stored Procedure
CREATE PROCEDURE [dbo].[BalancePerCustomer]
	@name NVARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		DimCustomer.CustomerName,
		DimAccount.AccountType,
		DimAccount.Balance,
		DimAccount.Balance +
			SUM(CASE
				WHEN FactTransaction.transaction_type = 'Deposit' THEN FactTransaction.amount
				ELSE -FactTransaction.amount
			END) AS CurrentBalance
	FROM
		DimCustomer
	JOIN
		DimAccount ON DimCustomer.CustomerID = DimAccount.CustomerID
	LEFT JOIN
		FactTransaction ON DimAccount.AccountID = FactTransaction.account_id
	WHERE
		DimCustomer.CustomerName LIKE '%' + @name + '%'
		AND DimAccount.Status = 'Active'
	GROUP BY
		DimCustomer.CustomerName,
        DimAccount.AccountType,
        DimAccount.Balance -- balance sama namun transaction amount bisa berbeda (penarikan dan pemasukan)
	ORDER BY
        DimAccount.AccountType;
		
END

GO
/****** Object:  StoredProcedure [dbo].[DailyTransaction]    Script Date: 04/02/2025 00:15:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Daily Transaction Stored Procedure
CREATE PROCEDURE [dbo].[DailyTransaction]
	@start_date DATE,
    @end_date DATE
AS
BEGIN
	SET NOCOUNT ON; -- Menghindari pesan jumlah baris terpengaruh
	
	SELECT
		CAST(transaction_date AS DATE) AS Date, -- Datetime to date data type(CASE)
		COUNT(*) AS TotalTransactions, -- Jumlah transaksi yang terjadi
		SUM(amount) AS TotalAmount -- Jumlah selurruh transaksi
	FROM
		FactTransaction -- dari tabel FactTransaction
	WHERE
        transaction_date >= @start_date -- kondisi, dimana mengambil data pada tanggal sekian sampai sekian
        AND transaction_date <= @end_date 
    GROUP BY
        CAST(transaction_date AS DATE) -- dikelompokkan berdasarkan hari yang sama
    ORDER BY
        Date; -- mengurutkan data berdasarkan tanggal
END
GO
