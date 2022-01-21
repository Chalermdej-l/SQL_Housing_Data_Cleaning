--This project import data using Bulk and rowset mthod and clean data for better use by convert data, format split address, add and delete column, remove duplicate
--

-- Create a table for Data to insert
create table HosingPrice
(
UniqueID int
  ,ParcelID nvarchar(255)
      ,LandUse nvarchar(255)
      ,PropertyAddress nvarchar(255)
	  ,SaleDate datetime
      ,SalePrice int
      ,LegalReference nvarchar(255)
      ,SoldAsVacant nvarchar(255)
	  ,OwnerName nvarchar(255)
	  ,OwnerAddress nvarchar(255)
      ,Acreage float
	  ,TaxDistrict nvarchar(255) 
      ,LandValue int
      ,BuildingValue int
      ,TotalValue int
      ,YearBuilt int
      ,Bedrooms int
      ,FullBath int
      ,HalfBath int
	  )
	  	   
--- Importing Data using OPENROWSET or BULK INSERT	

-- Config server to allow import data
sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO


USE PortfolioProject 

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1 

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1 

GO 


-- Insert Data using BULK INSERT method in CSV Format 
-- Noted that with this method I replace ',' with '.' in the address column in order to import the data in

USE PortfolioProject;
GO
BULK INSERT HosingPrice FROM 'C:\Nashville Housing Data for Data Cleaning.csv'
   WITH (
	 FIRSTROW = 2,
      FIELDTERMINATOR = ',',
      ROWTERMINATOR = '\n'
);
GO

-- Insert Data using OPENROWSET method in XLSX Format

insert into HosingPrice
SELECT *
FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0; Database=C:\Nashville Housing Data for Data Cleaning.xlsx','SELECT * FROM [Sheet1$]');
GO

-- Config server back to default

USE PortfolioProject 

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 0

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 0 

GO 

sp_configure 'Ad Hoc Distributed Queries', 0;
RECONFIGURE;
GO

sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

--Select data
select *
from HosingPrice

--Change format of date into a new column
select SaleDate, convert(date,SaleDate)
from HosingPrice

alter table HosingPrice
add Converteddate Date

update HosingPrice
set Converteddate = convert(date,SaleDate)

--Change Parcell ID format replace " " with "-" and replace the delimeter
select ParcelID,replace(LEFT(ParcelID,len(ParcelID)-3),' ','-')
from HosingPrice

update HosingPrice
set ParcelID = replace(LEFT(ParcelID,len(ParcelID)-3),' ','-')

--Update Property Address fill in null value
select ParcelID,PropertyAddress
from HosingPrice
where PropertyAddress is null

select a.ParcelID,a.PropertyAddress,b.ParcelID,b.PropertyAddress,iSNULL(a.propertyaddress,b.PropertyAddress)
from HosingPrice a
join HosingPrice b
on a.ParcelID = b.ParcelID
and a.[UniqueID ] <> b.[UniqueID ]
where a.PropertyAddress is null

update a
set PropertyAddress = iSNULL(a.propertyaddress,b.PropertyAddress)
from HosingPrice a
join HosingPrice b
on a.ParcelID = b.ParcelID
and a.[UniqueID ] <> b.[UniqueID ]
where a.PropertyAddress is null

-- Sperate address into category

alter table HosingPrice --Add Tabel for the adjust Property address
add PropertySplitAddress nvarchar(255),PropertySplitCity nvarchar(255)

update HosingPrice -- Add value into the new column
set PropertySplitAddress = substring(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1),
	PropertySplitCity = substring(PropertyAddress,CHARINDEX(',',PropertyAddress)+1,(LEN(PropertyAddress)-CHARINDEX(',',PropertyAddress)+1))

alter table HosingPrice --Add Tabel for the adjust Owner address
add OwnerSplitTown nvarchar(255),OwnerSplitCity nvarchar(255),OwnerSplitAddress nvarchar(255)

update HosingPrice -- Add value into the new column
set OwnerSplitTown = parsename(replace(OwnerAddress,',','.'),1),
	OwnerSplitCity = parsename(replace(OwnerAddress,',','.'),2),
	OwnerSplitAddress = parsename(replace(OwnerAddress,',','.'),3)

-- Change Y and N in SoldAsvacant column into Yes and No
select distinct(SoldAsVacant)
from HosingPrice

update HosingPrice
set SoldAsVacant = 
case
	when SoldAsVacant = 'Y' then 'Yes'
	when SoldAsVacant = 'N' then 'No'
	else SoldAsVacant
end
from HosingPrice

--Delete duplicate data
with cte as
(
select *,
	ROW_NUMBER() over (partition by ParcelID,
									PropertyAddress,
									SalePrice,
									LegalReference,
									OwnerName
									order by
									UniqueID
									) As Rownum
from HosingPrice
)
delete from cte
where Rownum  > 1

-- Delete Unuse column
alter table HosingPrice
drop column OwnerAddress,TaxDistrict,SaleDate

select *
from HosingPrice
order by 1


